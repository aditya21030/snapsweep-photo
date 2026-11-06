package com.yousful.snapsweep

import android.app.Activity
import android.content.ContentUris
import android.graphics.Bitmap
import android.os.Build
import android.provider.MediaStore
import android.util.Size
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/** Bounded, bitmap-only processing. No JPEG round trips through Dart or temp files. */
class MediaClassifier(private val activity: Activity) {
    private class Worker {
        val labeler = ImageLabeling.getClient(ImageLabelerOptions.Builder().setConfidenceThreshold(0.5f).build())
        val text = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        fun close() { labeler.close(); text.close() }
    }
    private val inferenceCache = ConcurrentHashMap<String, Map<String, Any>>()
    private val workers = ConcurrentLinkedQueue<Worker>()
    private val local = object : ThreadLocal<Worker>() {
        override fun initialValue(): Worker = Worker().also { workers.add(it) }
    }
    private val executor = Executors.newFixedThreadPool(2)
    private val catalogExecutor = Executors.newSingleThreadExecutor()
    @Volatile private var closed = false

    fun analyze(items: List<Map<String, Any?>>, result: MethodChannel.Result) {
        if (closed || items.size > 8) { result.error("INVALID_BATCH", "Expected at most eight images", null); return }
        if (items.isEmpty()) { result.success(emptyList<Any>()); return }
        val remaining = AtomicInteger(items.size)
        val output = java.util.Collections.synchronizedList(mutableListOf<Map<String, Any?>>())
        for (item in items) executor.execute {
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_BACKGROUND)
            val id = item["id"] as? String ?: ""
            val outputRow = mutableMapOf<String, Any?>("id" to id, "ok" to true)
            try {
                val uri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id.toLong())
                fun thumbnail(size: Int): Bitmap {
                    val bitmap = if (Build.VERSION.SDK_INT >= 29) {
                        activity.contentResolver.loadThumbnail(uri, Size(size, size), null)
                    } else {
                        @Suppress("DEPRECATION")
                        MediaStore.Images.Thumbnails.getThumbnail(activity.contentResolver, id.toLong(), MediaStore.Images.Thumbnails.MINI_KIND, null)
                            ?: throw IllegalStateException("Thumbnail unavailable")
                    }
                    val software = if (Build.VERSION.SDK_INT >= 26 && bitmap.config == Bitmap.Config.HARDWARE) {
                        bitmap.copy(Bitmap.Config.ARGB_8888, false) ?: throw IllegalStateException("Bitmap conversion unavailable")
                    } else bitmap
                    val longest = maxOf(software.width, software.height)
                    return if (longest > size) Bitmap.createScaledBitmap(software, maxOf(1, software.width * size / longest), maxOf(1, software.height * size / longest), true) else software
                }
                var digest: String? = null
                if (item["verifyBytes"] == true) {
                    try {
                        val md5 = MessageDigest.getInstance("MD5")
                        var count = 0L
                        activity.contentResolver.openInputStream(uri)?.use { stream ->
                            val bytes = ByteArray(65536)
                            var n = stream.read(bytes)
                            while (n >= 0) {
                                if (Thread.currentThread().isInterrupted) throw InterruptedException()
                                if (n > 0) { md5.update(bytes, 0, n); count += n }
                                n = stream.read(bytes)
                            }
                        }
                        if (count > 0) digest = md5.digest().joinToString("") { "%02x".format(it.toInt() and 255) }
                        outputRow["verifiedMd5"] = digest
                    } catch (_: Exception) { outputRow["verifiedMd5"] = null }
                }
                val classify = item["classify"] != false
                val bitmap = if (classify || item["hash"] == true) thumbnail(if (classify) 320 else 96) else null
                if (item["hash"] == true && bitmap != null) {
                    val tiny = Bitmap.createScaledBitmap(bitmap, 9, 9, false)
                    val pixels = IntArray(81)
                    tiny.getPixels(pixels, 0, 9, 0, 0, 9, 9)
                    fun luminance(index: Int): Int {
                        val c = pixels[index]
                        return 299 * ((c shr 16) and 255) + 587 * ((c shr 8) and 255) + 114 * (c and 255)
                    }
                    val hash = StringBuilder(128)
                    for (y in 0..7) for (x in 0..7) hash.append(if (luminance(y * 9 + x) > luminance(y * 9 + x + 1)) '1' else '0')
                    for (y in 0..7) for (x in 0..7) hash.append(if (luminance(y * 9 + x) > luminance((y + 1) * 9 + x)) '1' else '0')
                    outputRow["dHash"] = hash.toString()
                }
                if (classify && bitmap != null) {
                    val worker = local.get()!!
                    val cached = digest?.let { inferenceCache[it] }
                    if (cached != null && (item["readText"] != true || (cached["text"] as? String).orEmpty().isNotEmpty())) {
                        outputRow.putAll(cached)
                    } else {
                        val image = InputImage.fromBitmap(bitmap, 0)
                        val labels = Tasks.await(worker.labeler.process(image), 10, TimeUnit.SECONDS)
                        val evidence = labels.associate { it.text.lowercase() to it.confidence.toDouble() }
                        val textHints = setOf("receipt", "paper", "passport", "web page", "money", "handwriting", "whiteboard", "menu")
                        val needsText = item["readText"] == true || labels.any { it.confidence >= 0.75 && it.text.lowercase() in textHints }
                        var text = ""
                        if (needsText) {
                            try { text = Tasks.await(worker.text.process(InputImage.fromBitmap(thumbnail(768), 0)), 10, TimeUnit.SECONDS).text }
                            catch (_: Exception) { }
                        }
                        val inference = mapOf<String, Any>("labels" to evidence, "text" to text)
                        outputRow.putAll(inference)
                        if (digest != null) {
                            if (inferenceCache.size >= 512) inferenceCache.clear()
                            inferenceCache[digest] = inference
                        }
                    }
                }
                output.add(outputRow)
            } catch (_: Exception) {
                outputRow["ok"] = outputRow["verifiedMd5"] != null || outputRow["dHash"] != null
                output.add(outputRow)
            }
            if (remaining.decrementAndGet() == 0 && !closed) {
                val response = synchronized(output) { output.toList() }
                activity.runOnUiThread { if (!closed) result.success(response) }
            }
        }
    }

    fun mediaFacts(result: MethodChannel.Result) {
        if (closed) { result.error("CLOSED", "Classifier closed", null); return }
        catalogExecutor.execute {
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_BACKGROUND)
            try {
                val output = mutableMapOf<String, Map<String, Any>>()
                val columns = arrayOf("_id", "_size", "date_modified", "_data")
                activity.contentResolver.query(MediaStore.Files.getContentUri("external"), columns, "media_type IN (1,3)", null, null)?.use { cursor ->
                    val id = cursor.getColumnIndexOrThrow("_id")
                    val size = cursor.getColumnIndexOrThrow("_size")
                    val modified = cursor.getColumnIndexOrThrow("date_modified")
                    val path = cursor.getColumnIndex("_data")
                    while (cursor.moveToNext()) output[cursor.getLong(id).toString()] = mapOf(
                        "size" to cursor.getLong(size), "modified" to cursor.getLong(modified),
                        "path" to if (path >= 0) cursor.getString(path).orEmpty() else ""
                    )
                }
                activity.runOnUiThread { if (!closed) result.success(output) }
            } catch (error: Exception) {
                activity.runOnUiThread { if (!closed) result.error("CATALOG", error.message, null) }
            }
        }
    }

    fun close() {
        closed = true
        executor.shutdownNow()
        catalogExecutor.shutdownNow()
        Thread {
            if (executor.awaitTermination(30, TimeUnit.SECONDS)) workers.forEach { it.close() }
        }.start()
    }
}
