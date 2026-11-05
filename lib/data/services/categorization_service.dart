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

  // High-confidence Person & Portrait ML labels
  static const Set<String> _personLabels = {
    'person', 'people', 'human', 'man', 'woman', 'girl', 'boy', 'child', 'baby',
    'selfie', 'portrait', 'smile', 'facial expression', 'head', 'face', 'forehead',
    'friendship', 'family', 'cheering', 'crowd', 'eyewear', 'sunglasses', 'toddler',
    'clothing', 'outerwear', 'dress', 'fashion', 'suit', 'jeans', 't-shirt', 'shirt',
    'jacket', 'footwear', 'shoe', 'pants', 'trousers', 'lady', 'male', 'female', 'kid',
    'bride', 'groom', 'wedding', 'standing', 'sitting', 'posing', 'model', 'beauty',
    'fun', 'vacation', 'holiday', 'leisure', 'party', 'athlete', 'player', 'spectator',
  };

  // High-confidence Food & Dining ML labels
  static const Set<String> _foodLabels = {
    'food', 'dish', 'cuisine', 'meal', 'dessert', 'snack', 'tableware', 'ingredient',
    'recipe', 'meat', 'vegetable', 'fruit', 'drink', 'beverage', 'cocktail', 'coffee',
    'fast food', 'baked goods', 'bread', 'cake', 'pizza', 'burger', 'noodle',
    'rice', 'curry', 'salad', 'seafood', 'soup', 'plate', 'bowl', 'culinary',
    'restaurant', 'pasta', 'cheese', 'ice cream', 'breakfast', 'lunch', 'dinner',
    'sandwich', 'pastry', 'cookie', 'juice', 'alcohol', 'beer', 'wine', 'barbecue',
    'tea', 'steak', 'chicken', 'roast', 'baking', 'cup', 'mug', 'produce', 'apple',
    'banana', 'orange', 'strawberry', 'chocolate', 'sweet', 'candy', 'ramen', 'fish',
    'brunch', 'cafe', 'bakery', 'diner', 'bbq', 'cooking',
  };

  // High-confidence Document & Text ML labels
  static const Set<String> _docLabels = {
    'document', 'paper', 'receipt', 'invoice', 'bill', 'handwriting',
    'identity document', 'passport', 'driver\'s license', 'certificate',
    'ticket', 'business card', 'flyer', 'page', 'text', 'font', 'newspaper',
    'book', 'envelope', 'publication', 'letter', 'sheet music', 'diagram',
    'line art', 'monochrome', 'sign', 'whiteboard', 'blackboard', 'form',
    'contract', 'statement', 'prescription', 'menu', 'pamphlet', 'brochure',
  };

  // High-confidence Meme & Graphics ML labels
  static const Set<String> _memeLabels = {
    'cartoon', 'comics', 'illustration', 'animated cartoon', 'meme', 'clip art',
    'fictional character', 'caricature', 'drawing', 'art', 'graphic design',
    'anime', 'manga', 'animation', 'sticker', 'emoji',
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
  /// Screenshots check runs FIRST so app-name screenshots stay in Screenshots.
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
        album.contains('screencapture') || path.contains('screenshots') || path.contains('screen_shot');
    final bool isScreenshotTitle = title.startsWith('screenshot') || title.startsWith('screen_shot') ||
        title.contains('screenshot_') || title.contains('scrn_') || title.contains('s_shot') || title.startsWith('screen_');

    if (isScreenshotFolder || isScreenshotTitle) {
      return 'Screenshots';
    }

    // Modern phone display aspect ratio (18.5:9 to 22:9) with typical screenshot naming or PNG format
    if (asset.width > 0 && asset.height > 0) {
      final longer = max(asset.width, asset.height);
      final shorter = min(asset.width, asset.height);
      final ratio = longer / shorter;
      if (ratio >= 1.95 && ratio <= 2.35 && (title.endsWith('.png') || path.contains('screenshots') || album.contains('pictures'))) {
        return 'Screenshots';
      }
    }

    // 3. Authoritative Social Media / Messaging bucket or title tags
    if (album.contains('whatsapp') || path.contains('whatsapp') ||
        album.contains('telegram') || path.contains('telegram') ||
        album.contains('snapchat') || path.contains('snapchat') ||
        album.contains('instagram') || path.contains('instagram') ||
        album.contains('facebook') || path.contains('facebook') ||
        album.contains('messenger') || path.contains('messenger') ||
        album.contains('signal') || path.contains('signal') ||
        album.contains('twitter') || path.contains('twitter') ||
        album.contains('threads') || path.contains('threads') ||
        album.contains('discord') || path.contains('discord')) {
      return 'Social & WhatsApp';
    }
    if (title.contains('-wa') || title.contains('_wa') || title.startsWith('wa') ||
        title.contains('tg_') || title.startsWith('fb_img') || title.startsWith('instagram_')) {
      return 'Social & WhatsApp';
    }

    // 4. Authoritative Downloads / Memes bucket
    if (album.contains('download') || path.contains('download') ||
        album.contains('reddit') || path.contains('reddit') ||
        album.contains('9gag') || path.contains('9gag') ||
        album.contains('pinterest') || path.contains('pinterest') ||
        album.contains('meme') || path.contains('meme')) {
      return 'Memes & Downloads';
    }

    // 5. Authoritative Document scanners bucket
    if (album.contains('camscanner') || album.contains('adobe scan') || album.contains('documents') ||
        path.contains('camscanner') || path.contains('adobescan') || album.contains('scanner') ||
        album.contains('receipt') || album.contains('invoice')) {
      return 'Documents & IDs';
    }

    // 6. Food & Dining album hints
    if (album.contains('food') || album.contains('recipe') || album.contains('restaurant') || album.contains('cooking')) {
      return 'Food & Dining';
    }

    // 7. Explicit Portraits & Selfies album hints
    if (album.contains('selfie') || album.contains('portrait') || album.contains('portraits') || album.contains('front camera')) {
      return 'Personal & Portraits';
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
        return 'Others';
      }

      final inputImage = InputImage.fromFile(file);

      // Signal 1: Real ML Kit Face Detection on the 360x360 thumbnail
      // Any detected face with width >= 25 in the 360px thumbnail is a genuine person/portrait
      try {
        final faces = await _faceDetector.processImage(inputImage);
        if (faces.isNotEmpty) {
          bool hasValidFace = false;
          for (final face in faces) {
            if (face.boundingBox.width >= 25 && face.boundingBox.height >= 25) {
              hasValidFace = true;
              break;
            }
          }
          if (hasValidFace || faces.length >= 2) {
            scores['Personal & Portraits'] = (scores['Personal & Portraits'] ?? 0.0) + 3.5;
          }
        }
      } catch (_) {}

      // Signal 2: On-device Image Labeling at >= 0.40 confidence threshold
      final labels = await _imageLabeler.processImage(inputImage);
      bool hasTextHint = false;

      for (final l in labels) {
        final label = l.label.toLowerCase();
        final conf = l.confidence;

        // Person / Portrait visual match
        if (conf >= 0.45 && _personLabels.contains(label)) {
          scores['Personal & Portraits'] = (scores['Personal & Portraits'] ?? 0.0) + 3.0;
        }

        // Food & Dining visual match
        if (conf >= 0.45 && _foodLabels.contains(label)) {
          scores['Food & Dining'] = (scores['Food & Dining'] ?? 0.0) + 3.5;
        }

        // Document / Receipt visual match
        if (conf >= 0.45 && _docLabels.contains(label)) {
          scores['Documents & IDs'] = (scores['Documents & IDs'] ?? 0.0) + 2.5;
        }

        // Meme / Cartoon visual match
        if (conf >= 0.45 && _memeLabels.contains(label)) {
          scores['Memes & Downloads'] = (scores['Memes & Downloads'] ?? 0.0) + 3.0;
        }

        // Gate for OCR: label hints at text, font, paper, or document
        if (label.contains('text') || label.contains('font') || label.contains('paper') ||
            label.contains('document') || label.contains('receipt') || label.contains('web page')) {
          hasTextHint = true;
        }
      }

      // Signal 3: High-Resolution (1024px) OCR for Documents & Receipts
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
              scores['Bills & Finance'] = (scores['Bills & Finance'] ?? 0.0) + 4.0;
            }

            // Documents & IDs: Govt IDs (Aadhaar, PAN, DL) or document keywords
            if (_aadhaarRegex.hasMatch(ocr) || _panRegex.hasMatch(ocr) || _dlRegex.hasMatch(ocr) || _docKeywordsRegex.hasMatch(ocr)) {
              scores['Documents & IDs'] = (scores['Documents & IDs'] ?? 0.0) + 4.0;
            }

            // Memes & Downloads: Meme slang phrases
            if (ocr.length <= 160 && _memeSlangRegex.hasMatch(ocr)) {
              scores['Memes & Downloads'] = (scores['Memes & Downloads'] ?? 0.0) + 2.5;
            }

            // Long printed text block indicator
            if (ocr.length > 50 || recognizedText.blocks.length >= 2) {
              scores['Documents & IDs'] = (scores['Documents & IDs'] ?? 0.0) + 2.5;
            }
          }
        }
      }

      // Multi-Signal Scoring Decision:
      // Sort categories by accumulated score descending
      final sortedEntries = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final top = sortedEntries[0];

      // Any category with score >= 1.5 wins (indicates solid visual or textual match)
      if (top.value >= 1.5) {
        return top.key;
      }

      // If photo was captured by user camera roll, classify to Personal & Portraits if any person/clothing signal exists
      final album = (albumName ?? '').toLowerCase();
      final path = (asset.relativePath ?? '').toLowerCase();
      final bool isCameraRoll = album.contains('camera') || album.contains('dcim') ||
          album.contains('100andro') || path.contains('dcim') || path.contains('camera');

      if (isCameraRoll) {
        if (top.value >= 0.8) {
          return top.key;
        }
        if ((scores['Personal & Portraits'] ?? 0.0) > 0.0) {
          return 'Personal & Portraits';
        }
      }

      // Only unclassified miscellaneous photos (corrupt images, random textures) return 'Others'
      return 'Others';
    } catch (e) {
      debugPrint('[Categorization ML Error] $e');
      return 'Others';
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
}
