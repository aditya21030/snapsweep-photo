import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:photo_manager/photo_manager.dart';

class CategoryResult {
  final String category;
  final double score;
  final String? debugInfo;

  CategoryResult(this.category, {this.score = 0.0, this.debugInfo});
}

class CategorizationService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.40));
  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours: false,
      enableLandmarks: false,
      enableClassification: false,
    ),
  );

  static const List<String> availableCategories = [
    'Screenshots',
    'Screen Recordings',
    'Social & WhatsApp',
    'Bills & Finance',
    'Documents & IDs',
    'Food & Dining',
    'Memes & Downloads',
    'Personal & Portraits',
    'Others',
  ];

  // Specific high-confidence Food & Dining ML labels
  static const Set<String> _foodLabels = {
    'food', 'dish', 'cuisine', 'meal', 'dessert', 'snack', 'tableware', 'ingredient',
    'recipe', 'meat', 'vegetable', 'fruit', 'drink', 'beverage', 'cocktail', 'coffee',
    'fast food', 'baked goods', 'bread', 'cake', 'pizza', 'burger', 'noodle',
    'rice', 'curry', 'salad', 'seafood', 'soup', 'plate', 'bowl', 'culinary',
    'restaurant', 'pasta', 'cheese', 'ice cream', 'breakfast', 'lunch', 'dinner',
    'sandwich', 'pastry', 'cookie', 'juice', 'alcohol', 'beer', 'wine', 'barbecue',
  };

  // Specific high-confidence Document ML labels
  static const Set<String> _docLabels = {
    'document', 'paper', 'receipt', 'invoice', 'bill', 'handwriting',
    'identity document', 'passport', 'driver\'s license', 'certificate',
    'ticket', 'business card', 'flyer', 'page',
  };

  // Specific high-confidence Meme ML labels
  static const Set<String> _memeLabels = {
    'cartoon', 'comics', 'illustration', 'animated cartoon', 'meme', 'clip art',
    'fictional character', 'caricature',
  };

  // Regexes with strict word boundaries and required tokens
  static final RegExp _currencyRegex = RegExp(r'\b(?:₹|rs\.?|inr|\$|€|£)\s*\d+(?:[.,]\d{2})?', caseSensitive: false);
  static final RegExp _transactionRegex = RegExp(r'\b(?:gstin|txn\s*id|transaction\s*id|upi\s*ref|invoice\s*no|subtotal|grand\s*total|net\s*payable|amount\s*paid|paid\s*to|transfer\s*successful)\b', caseSensitive: false);
  static final RegExp _aadhaarRegex = RegExp(r'\b\d{4}\s\d{4}\s\d{4}\b');
  static final RegExp _panRegex = RegExp(r'\b[A-Z]{5}[0-9]{4}[A-Z]\b', caseSensitive: false);
  static final RegExp _dlRegex = RegExp(r'\b[A-Z]{2}[-\s]?\d{2}[-\s]?\d{4}[-\s]?\d{7}\b', caseSensitive: false);
  static final RegExp _memeSlangRegex = RegExp(r'\b(?:when you|me when|nobody:|pov|relatable|literally|bruh|bro|tbh|lmao|lol)\b', caseSensitive: false);

  // Authoritative document keywords requiring word boundaries
  static final RegExp _docKeywordsRegex = RegExp(r'\b(?:aadhaar|aadhar|government of india|income tax department|permanent account number|pan card|pancard|driving license|driving licence|voter id|election commission|marksheet|admit card|hall ticket|salary slip|form 16|prescription|camscanner|adobe scan)\b', caseSensitive: false);

  // Authoritative finance keywords requiring word boundaries
  static final RegExp _financeKeywordsRegex = RegExp(r'\b(?:gpay|paytm|phonepe|bhim|razorpay|bharatpe|passbook|bank statement|cash receipt|net banking|imps|neft)\b', caseSensitive: false);

  void dispose() {
    _textRecognizer.close();
    _imageLabeler.close();
    _faceDetector.close();
  }

  /// Instant metadata-based categorization for clearly defined buckets.
  /// Fix Bug 2: Screenshots check runs FIRST so app-name screenshots (e.g. Screenshot_Zomato) stay in Screenshots.
  String? quickCategorize(AssetEntity asset, {String? albumName}) {
    final title = (asset.title ?? '').toLowerCase();
    final path = (asset.relativePath ?? '').toLowerCase();
    final album = (albumName ?? '').toLowerCase();

    // 1. Screen Recordings (Videos)
    if (asset.type == AssetType.video) {
      if (album.contains('screen') || path.contains('screen') || title.contains('screen') ||
          album.contains('record') || path.contains('record') || title.contains('screencast')) {
        return 'Screen Recordings';
      }
      if (album.contains('whatsapp') || path.contains('whatsapp') || album.contains('telegram') || path.contains('telegram')) {
        return 'Social & WhatsApp';
      }
      return null;
    }

    // 2. Authoritative Screenshots (Checked BEFORE app-names so Screenshot_Zomato stays in Screenshots)
    final bool isScreenshotFolder = album.contains('screenshot') || album.contains('screen shot') ||
        path.contains('screenshots') || path.contains('screen_shot');
    final bool isScreenshotTitle = title.startsWith('screenshot') || title.startsWith('screen_shot') ||
        title.contains('screenshot_') || title.contains('scrn_') || title.contains('s_shot');

    if (isScreenshotFolder || isScreenshotTitle) {
      return 'Screenshots';
    }

    // Modern phone display aspect ratio (19:9 to 21.5:9) with PNG format or DCIM/Screenshots path
    if (asset.width > 0 && asset.height > 0) {
      final longer = max(asset.width, asset.height);
      final shorter = min(asset.width, asset.height);
      final ratio = longer / shorter;
      if (ratio >= 1.95 && ratio <= 2.35 && (title.endsWith('.png') || path.contains('screenshots'))) {
        return 'Screenshots';
      }
    }

    // 3. Authoritative Social Media / WhatsApp bucket or title tags
    if (album.contains('whatsapp') || path.contains('whatsapp') ||
        album.contains('telegram') || path.contains('telegram') ||
        album.contains('snapchat') || path.contains('snapchat') ||
        album.contains('instagram') || path.contains('instagram')) {
      return 'Social & WhatsApp';
    }
    if (title.contains('-wa') || title.contains('_wa') || title.startsWith('wa') || title.contains('tg_')) {
      return 'Social & WhatsApp';
    }

    // 4. Authoritative Downloads / Memes bucket
    if (album.contains('download') || path.contains('download') ||
        album.contains('reddit') || path.contains('reddit') ||
        album.contains('9gag') || path.contains('9gag')) {
      return 'Memes & Downloads';
    }

    // 5. Authoritative Document scanners bucket
    if (album.contains('camscanner') || album.contains('adobe scan') || album.contains('documents') ||
        path.contains('camscanner') || path.contains('adobescan')) {
      return 'Documents & IDs';
    }

    // Return null for ambiguous or Camera roll photos so they proceed to visual ML analysis
    return null;
  }

  /// Advanced ML Content Classifier with Multi-Signal Voting Engine.
  /// Implements real ML Kit Face Detection, 1024px thumbnail OCR, and multi-signal scoring.
  Future<String> categorizeWithML(AssetEntity asset, {String? albumName}) async {
    final quick = quickCategorize(asset, albumName: albumName);
    if (quick != null) return quick;

    // Multi-signal score accumulator
    final Map<String, double> scores = {
      'Personal & Portraits': 0.0,
      'Food & Dining': 0.0,
      'Bills & Finance': 0.0,
      'Documents & IDs': 0.0,
      'Memes & Downloads': 0.0,
      'Screenshots': 0.0,
      'Screen Recordings': 0.0,
      'Social & WhatsApp': 0.0,
    };

    File? tempFile;
    File? ocrTempFile;
    try {
      // 1. Fetch 360px thumbnail for fast visual labeling and face detection
      Uint8List? thumbBytes;
      try {
        thumbBytes = await asset.thumbnailDataWithSize(const ThumbnailSize.square(360));
      } catch (_) {}

      File? file;
      if (thumbBytes != null && thumbBytes.isNotEmpty) {
        final tempDir = Directory.systemTemp;
        tempFile = File('${tempDir.path}/snapsweep_ml_${asset.id.hashCode}_${DateTime.now().microsecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(thumbBytes, flush: true);
        file = tempFile;
      } else {
        file = await asset.file;
      }

      if (file == null || !await file.exists()) {
        return _fallbackCategory(asset, albumName: albumName);
      }

      final inputImage = InputImage.fromFile(file);

      // Signal 1: Real ML Kit Face Detection for Portraits
      // If a face covers >= 8% of the frame, strongly vote for Personal & Portraits (+3.0)
      try {
        final faces = await _faceDetector.processImage(inputImage);
        if (faces.isNotEmpty) {
          final imgWidth = (asset.width > 0 ? asset.width : 360).toDouble();
          final imgHeight = (asset.height > 0 ? asset.height : 360).toDouble();
          final totalArea = imgWidth * imgHeight;

          bool significantFaceFound = false;
          for (final face in faces) {
            final faceArea = face.boundingBox.width * face.boundingBox.height;
            if (totalArea > 0 && (faceArea / totalArea) >= 0.08) {
              significantFaceFound = true;
              break;
            }
          }
          if (significantFaceFound || faces.length >= 2) {
            scores['Personal & Portraits'] = (scores['Personal & Portraits'] ?? 0.0) + 3.0;
          }
        }
      } catch (_) {}

      // Signal 2: On-device Image Labeling at >= 0.6 confidence threshold
      final labels = await _imageLabeler.processImage(inputImage);
      int foodLabelHits = 0;
      double maxFoodConf = 0.0;
      bool hasTextHint = false;

      for (final l in labels) {
        final label = l.label.toLowerCase();
        final conf = l.confidence;

        if (_foodLabels.contains(label)) {
          foodLabelHits++;
          if (conf > maxFoodConf) maxFoodConf = conf;
        }

        if (conf >= 0.60) {
          if (_docLabels.contains(label)) {
            scores['Documents & IDs'] = (scores['Documents & IDs'] ?? 0.0) + 2.0;
          }
          if (_memeLabels.contains(label)) {
            scores['Memes & Downloads'] = (scores['Memes & Downloads'] ?? 0.0) + 2.0;
          }
        }

        // Gate for OCR: label hints at text, font, paper, or document
        if (label.contains('text') || label.contains('font') || label.contains('paper') ||
            label.contains('document') || label.contains('receipt') || label.contains('web page')) {
          hasTextHint = true;
        }
      }

      // Food scoring rule: require >= 2 food labels or 1 label at >= 0.70 confidence
      if (foodLabelHits >= 2 || maxFoodConf >= 0.70) {
        scores['Food & Dining'] = (scores['Food & Dining'] ?? 0.0) + 2.5;
      }

      // Signal 3: High-Resolution (1024px) OCR for Documents & Receipts
      // Gated so OCR only runs on candidate documents / text / screenshots, not every photo
      final bool needsOcr = hasTextHint || (scores['Documents & IDs'] ?? 0.0) > 0.0;
      if (needsOcr) {
        Uint8List? ocrBytes;
        try {
          ocrBytes = await asset.thumbnailDataWithSize(const ThumbnailSize.square(1024));
        } catch (_) {}

        File? ocrFile;
        if (ocrBytes != null && ocrBytes.isNotEmpty) {
          final tempDir = Directory.systemTemp;
          ocrTempFile = File('${tempDir.path}/snapsweep_ocr_${asset.id.hashCode}_${DateTime.now().microsecondsSinceEpoch}.jpg');
          await ocrTempFile.writeAsBytes(ocrBytes, flush: true);
          ocrFile = ocrTempFile;
        } else {
          ocrFile = file;
        }

        if (await ocrFile.exists()) {
          final ocrImage = InputImage.fromFile(ocrFile);
          final recognizedText = await _textRecognizer.processImage(ocrImage);
          final ocr = recognizedText.text.toLowerCase();

          if (ocr.length >= 6) {
            // Bills & Finance: Currency amount pairing or transaction keywords
            if (_currencyRegex.hasMatch(ocr) || _transactionRegex.hasMatch(ocr) || _financeKeywordsRegex.hasMatch(ocr)) {
              scores['Bills & Finance'] = (scores['Bills & Finance'] ?? 0.0) + 2.5;
            }

            // Documents & IDs: Govt IDs (Aadhaar, PAN, DL) or document keywords
            if (_aadhaarRegex.hasMatch(ocr) || _panRegex.hasMatch(ocr) || _dlRegex.hasMatch(ocr) || _docKeywordsRegex.hasMatch(ocr)) {
              scores['Documents & IDs'] = (scores['Documents & IDs'] ?? 0.0) + 2.5;
            }

            // Memes & Downloads: Meme slang phrases
            if (ocr.length <= 160 && _memeSlangRegex.hasMatch(ocr)) {
              scores['Memes & Downloads'] = (scores['Memes & Downloads'] ?? 0.0) + 1.5;
            }

            // Long printed text block indicator
            if (ocr.length > 80 || recognizedText.blocks.length >= 4) {
              scores['Documents & IDs'] = (scores['Documents & IDs'] ?? 0.0) + 1.5;
            }
          }
        }
      }

      // Multi-Signal Scoring Decision:
      // Sort categories by accumulated score descending
      final sortedEntries = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final top = sortedEntries[0];
      final runnerUp = sortedEntries[1];

      // Winner must achieve score >= 3.0 AND lead the runner-up by at least 1.5 points
      if (top.value >= 3.0 && (top.value - runnerUp.value) >= 1.5) {
        return top.key;
      }

      return 'Others';
    } catch (e) {
      debugPrint('[Categorization ML Error] $e');
      return _fallbackCategory(asset, albumName: albumName);
    } finally {
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) await tempFile.delete();
        } catch (_) {}
      }
      if (ocrTempFile != null) {
        try {
          if (await ocrTempFile.exists()) await ocrTempFile.delete();
        } catch (_) {}
      }
    }
  }

  String _fallbackCategory(AssetEntity asset, {String? albumName}) {
    // Unresolved assets default to 'Others' without guessing from aspect ratio
    return 'Others';
  }
}
