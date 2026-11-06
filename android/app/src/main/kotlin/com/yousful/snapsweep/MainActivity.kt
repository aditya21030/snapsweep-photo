package com.yousful.snapsweep

import android.content.Intent
import android.app.Activity
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var updateManager: AppUpdateManager
    private var updateResult: MethodChannel.Result? = null
    private val updateRequestCode = 4807
    private var classifier: MediaClassifier? = null
    private val CHANNEL = "com.yousful.snapsweep/gallery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        updateManager = AppUpdateManagerFactory.create(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.yousful.snapsweep/updates").setMethodCallHandler { call, result ->
            when (call.method) {
                "installedVersion" -> result.success(installedVersion())
                "check" -> updateManager.appUpdateInfo
                    .addOnSuccessListener { info ->
                        result.success(mapOf(
                            "installedVersion" to installedVersion(),
                            "availableVersion" to info.availableVersionCode(),
                            "availability" to info.updateAvailability(),
                            "immediateAllowed" to info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)
                        ))
                    }
                    .addOnFailureListener { result.error("UPDATE_CHECK_FAILED", it.message, null) }
                "startImmediate" -> {
                    if (updateResult != null) {
                        result.error("UPDATE_BUSY", "An update is already running.", null)
                    } else {
                        updateResult = result
                        updateManager.appUpdateInfo.addOnSuccessListener { info ->
                            if ((info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE ||
                                 info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) &&
                                info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)) {
                                try {
                                    @Suppress("DEPRECATION")
                                    val started = updateManager.startUpdateFlowForResult(
                                        info, this, AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build(), updateRequestCode)
                                    if (!started) finishUpdateResult("failed")
                                } catch (error: Exception) {
                                    finishUpdateResult("failed")
                                }
                            } else finishUpdateResult("unavailable")
                        }.addOnFailureListener { finishUpdateResult("failed") }
                    }
                }
                else -> result.notImplemented()
            }
        }
        classifier = MediaClassifier(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.yousful.snapsweep/classifier").setMethodCallHandler { call, result ->
            if (call.method == "analyzeBatch") {
                val items = call.argument<List<Map<String, Any?>>>("items") ?: emptyList()
                classifier?.analyze(items, result)
            } else if (call.method == "mediaFacts") {
                classifier?.mediaFacts(result)
            } else result.notImplemented()
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getAppVersion") {
                @Suppress("DEPRECATION")
                val info = packageManager.getPackageInfo(packageName, 0)
                val code = if (android.os.Build.VERSION.SDK_INT >= 28) info.longVersionCode else {
                    @Suppress("DEPRECATION")
                    info.versionCode.toLong()
                }
                result.success("Version ${info.versionName} (Build $code)")
            } else if (call.method == "openGalleryTrash") {
                val opened = openSystemGallery()
                result.success(opened)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        finishUpdateResult("interrupted")
        classifier?.close()
        classifier = null
        super.onDestroy()
    }

    @Suppress("DEPRECATION")
    private fun installedVersion(): Long {
        val info = packageManager.getPackageInfo(packageName, 0)
        return if (android.os.Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
    }

    private fun finishUpdateResult(outcome: String) {
        updateResult?.success(outcome)
        updateResult = null
    }

    @Deprecated("Uses Play's update request code")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == updateRequestCode) {
            finishUpdateResult(if (resultCode == Activity.RESULT_OK) "completed" else if (resultCode == Activity.RESULT_CANCELED) "cancelled" else "failed")
        }
    }

    private fun openSystemGallery(): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_APP_GALLERY)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                true
            } else {
                val fallback = Intent(Intent.ACTION_VIEW).apply {
                    type = "image/*"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(fallback)
                true
            }
        } catch (e: Exception) {
            false
        }
    }
}
