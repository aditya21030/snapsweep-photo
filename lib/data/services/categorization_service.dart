import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
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
  final _imageLabeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.40),
  );
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
    'Downloads',
    'Bills & Finance',
    'Documents & IDs',
    'Food & Dining',
    'Memes & Graphics',
    'Personal & Portraits',
    'Nature & Landscapes',
    'Travel & Places',
    'Pets & Animals',
    'Vehicles',
    'Shopping & Products',
    'Events & Celebrations',
    'Sports & Fitness',
    'Art & Design',
    'Photo Library',
    'Videos',
  ];

  static const Set<String> sourceCategories = {
    'Screenshots',
    'Screen Recordings',
    'Social & WhatsApp',
    'Downloads',
  };

  static const Map<String, Set<String>> contentLabels = {
    'Nature & Landscapes': {
      'lake',
      'river',
      'canyon',
      'glacier',
      'volcano',
      'flora',
      'dune',
      'prairie',
      'aurora',

      'landscape',
      'nature',
      'mountain',
      'beach',
      'forest',
      'flower',
      'plant',
      'waterfall',
      'sunset',
      'sky',
      'garden',
    },
    'Travel & Places': {
      'skyline',
      'skyscraper',
      'palace',
      'mosque',
      'church',
      'cathedral',
      'museum',
      'ruins',
      'backpacking',

      'landmark',
      'architecture',
      'building',
      'city',
      'temple',
      'tower',
      'castle',
      'bridge',
      'airport',
      'monument',
    },
    'Pets & Animals': {
      'dalmatian',
      'shetland sheepdog',
      'cairn terrier',
      'basset hound',
      'sphynx',
      'ragdoll',
      'waterfowl',
      'turtle',
      'butterfly',
      'cattle',

      'dog',
      'cat',
      'pet',
      'animal',
      'bird',
      'horse',
      'wildlife',
      'insect',
    },
    'Vehicles': {
      'airliner',
      'aircraft',
      'van',
      'rickshaw',
      'helicopter',
      'sailboat',
      'tractor',

      'car',
      'vehicle',
      'motorcycle',
      'bicycle',
      'truck',
      'bus',
      'train',
      'airplane',
      'boat',
    },
    'Shopping & Products': {
      'jewellery',
      'necklace',
      'bracelet',
      'lipstick',
      'computer',
      'mobile phone',

      'product',
      'cosmetics',
      'jewelry',
      'handbag',
      'watch',
      'furniture',
      'electronic device',
    },
    'Events & Celebrations': {
      'marriage',
      'bride',
      'groom',
      'graduation',
      'christmas',
      'carnival',

      'wedding',
      'birthday',
      'festival',
      'concert',
      'fireworks',
      'celebration',
    },
    'Sports & Fitness': {
      'soccer',
      'cycling',
      'gymnastics',
      'surfing',
      'marathon',
      'badminton',

      'sport',
      'sports',
      'gym',
      'fitness',
      'basketball',
      'football',
      'tennis',
      'swimming',
      'exercise',
    },
    'Art & Design': {
      'watercolor paint',
      'statue',
      'crochet',
      'knitting',
      'needlework',
      'painting',
      'sculpture',
      'artwork',
      'drawing',
      'art',
    },
  };

  static double maxScore(double current, double candidate) =>
      current > candidate ? current : candidate;

  static String? categoryForLabel(String label) {
    final normalized = label.toLowerCase().trim();
    for (final entry in contentLabels.entries) {
      if (entry.value.contains(normalized)) return entry.key;
    }
    return null;
  }

  static String fallbackCategory(AssetEntity asset) =>
      asset.type == AssetType.video ? 'Videos' : 'Photo Library';

  // High-confidence Person & Portrait ML labels
  static const Set<String> _personLabels = {
    'person',
    'people',
    'human',
    'selfie',
    'portrait',
    'baby',
    'crowd',
    'family',
    'grandparent',
  };

  // High-confidence Food & Dining ML labels
  static const Set<String> _foodLabels = {
    'food',
    'bento',
    'cheeseburger',
    'hot dog',
    'couscous',
    'sushi',
    'pho',
    'gelato',
    'cappuccino',
    'supper',
    'pie',
    'menu',
    'dish',
    'cuisine',
    'meal',
    'dessert',
    'snack',
    'ingredient',
    'meat',
    'vegetable',
    'fruit',
    'drink',
    'beverage',
    'cocktail',
    'coffee',
    'fast food',
    'baked goods',
    'bread',
    'cake',
    'pizza',
    'burger',
    'noodle',
    'rice',
    'curry',
    'salad',
    'seafood',
    'soup',
    'culinary',
    'restaurant',
    'pasta',
    'cheese',
    'ice cream',
    'breakfast',
    'lunch',
    'dinner',
    'sandwich',
    'pastry',
    'cookie',
    'juice',
    'alcohol',
    'beer',
    'wine',
    'barbecue',
    'tea',
    'steak',
    'chicken',
    'roast',
    'baking',
    'produce',
    'apple',
    'banana',
    'orange',
    'strawberry',
    'chocolate',
    'sweet',
    'candy',
    'ramen',
    'brunch',
    'cafe',
    'bakery',
    'diner',
    'bbq',
    'cooking',
  };

  // High-confidence Document & Text ML labels
  static const Set<String> _docLabels = {
    'document',
    'screenshot',
    'web page',
    'money',
    'presentation',
    'paper',
    'receipt',
    'invoice',
    'bill',
    'handwriting',
    'identity document',
    'passport',
    'driver\'s license',
    'certificate',
    'ticket',
    'business card',
    'flyer',
    'page',
    'text',
    'font',
    'newspaper',
    'book',
    'envelope',
    'publication',
    'letter',
    'sheet music',
    'diagram',
    'whiteboard',
    'blackboard',
    'form',
    'contract',
    'statement',
    'prescription',
    'menu',
    'pamphlet',
    'brochure',
  };

  // High-confidence Meme & Graphics ML labels
  static const Set<String> _memeLabels = {
    'cartoon',
    'comics',
    'illustration',
    'animated cartoon',
    'meme',
    'clip art',
    'fictional character',
    'caricature',
    'graphic design',
    'anime',
    'manga',
    'animation',
    'sticker',
    'emoji',
  };

  // Regexes with strict word boundaries and required tokens
  static final RegExp _currencyRegex = RegExp(
    r'(?:[\u20b9$\u20ac\u00a3]|\b(?:rs\.?|inr)\s*)\s*\d+(?:[.,]\d{2})?',
    caseSensitive: false,
  );
  static final RegExp _transactionRegex = RegExp(
    r'\b(?:gstin|txn\s*id|transaction\s*id|upi\s*ref|invoice\s*no|subtotal|grand\s*total|net\s*payable|amount\s*paid|paid\s*to|transfer\s*successful|payment\s*successful|paid\s*successfully|payment\s*received|upi\s*transaction)\b',
    caseSensitive: false,
  );
  static final RegExp _aadhaarRegex = RegExp(r'\b\d{4}\s\d{4}\s\d{4}\b');
  static final RegExp _panRegex = RegExp(
    r'\b[A-Z]{5}[0-9]{4}[A-Z]\b',
    caseSensitive: false,
  );
  static final RegExp _dlRegex = RegExp(
    r'\b[A-Z]{2}[-\s]?\d{2}[-\s]?\d{4}[-\s]?\d{7}\b',
    caseSensitive: false,
  );
  static final RegExp _memeSlangRegex = RegExp(
    r'\b(?:when you|me when|nobody:|pov|relatable|literally|bruh|bro|tbh|lmao|lol)\b',
    caseSensitive: false,
  );

  // Authoritative document keywords requiring word boundaries
  static final RegExp _docKeywordsRegex = RegExp(
    r'\b(?:aadhaar|aadhar|government of india|income tax department|permanent account number|pan card|pancard|driving license|driving licence|voter id|election commission|marksheet|admit card|hall ticket|salary slip|form 16|prescription|camscanner|adobe scan)\b',
    caseSensitive: false,
  );

  // Authoritative finance keywords requiring word boundaries
  static final RegExp _financeKeywordsRegex = RegExp(
    r'\b(?:gpay|paytm|phonepe|bhim|razorpay|bharatpe|passbook|bank statement|cash receipt|net banking|imps|neft)\b',
    caseSensitive: false,
  );

  /// Deterministic decision layer shared by the native pipeline and regression tests.
  static String classifyEvidence(
    Map<String, double> rawLabels, {
    String text = '',
    bool hasFace = false,
  }) {
    final labels = <String, double>{};
    for (final entry in rawLabels.entries) {
      final key = entry.key.trim().toLowerCase();
      labels[key] = maxScore(labels[key] ?? 0, entry.value);
    }
    final ocr = text.toLowerCase();
    double confidence(Set<String> names) => names.fold<double>(
      0,
      (score, name) => maxScore(score, labels[name] ?? 0),
    );
    final documentSignal = confidence({
      'document',
      'paper',
      'handwriting',
      'whiteboard',
      'blackboard',
      'passport',
    });
    final graphicsSignal = confidence(_memeLabels);
    if (_docKeywordsRegex.hasMatch(ocr) || (labels['passport'] ?? 0) >= 0.8) {
      return 'Documents & IDs';
    }
    final financialContext =
        _transactionRegex.hasMatch(ocr) ||
        (_financeKeywordsRegex.hasMatch(ocr) && _currencyRegex.hasMatch(ocr));
    if (financialContext ||
        (labels['receipt'] ?? 0) >= 0.8 ||
        (_currencyRegex.hasMatch(ocr) &&
            confidence({'receipt', 'invoice', 'bill'}) >= 0.6)) {
      return 'Bills & Finance';
    }
    if (documentSignal >= 0.7 &&
        graphicsSignal < 0.7 &&
        (ocr.length > 100 ||
            _panRegex.hasMatch(ocr) ||
            _aadhaarRegex.hasMatch(ocr) ||
            _dlRegex.hasMatch(ocr))) {
      return 'Documents & IDs';
    }

    final scores = <String, double>{};
    void vote(String category, double confidence, double weight) {
      if (confidence >= 0.6) {
        scores[category] = maxScore(scores[category] ?? 0, confidence * weight);
      }
    }

    for (final category in contentLabels.entries) {
      vote(
        category.key,
        confidence(category.value),
        category.key == 'Nature & Landscapes' ? 3.3 : 4.2,
      );
    }
    vote('Food & Dining', confidence(_foodLabels), 4.2);
    vote('Memes & Graphics', graphicsSignal, 4.2);
    // Clothing, standing, sunglasses, art and text alone are not proof of a person or meme.
    vote('Personal & Portraits', confidence(_personLabels), 4.0);
    final eventConfidence = confidence(contentLabels['Events & Celebrations']!);
    if (hasFace && eventConfidence < 0.75) scores['Personal & Portraits'] = 4.5;
    if (eventConfidence >= 0.75) {
      scores.remove('Personal & Portraits');
      vote('Events & Celebrations', eventConfidence, 4.4);
    }
    if (documentSignal >= 0.8 &&
        ocr.trim().length >= 30 &&
        graphicsSignal < 0.7) {
      vote('Documents & IDs', documentSignal, 4.0);
    }
    // Slang is supporting evidence only; captions such as "lol" do not turn a photo into a meme.
    if (graphicsSignal >= 0.65 && _memeSlangRegex.hasMatch(ocr)) {
      scores['Memes & Graphics'] = 4.6;
    }
    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.isEmpty || ranked.first.value < 2.5) return 'Photo Library';
    if (ranked.length > 1 && ranked.first.value - ranked[1].value < 0.25) {
      return 'Photo Library';
    }
    return ranked.first.key;
  }

  void dispose() {
    unawaited(
      _textRecognizer.close().catchError((Object e) {
        debugPrint('OCR close: $e');
      }),
    );
    unawaited(
      _imageLabeler.close().catchError((Object e) {
        debugPrint('Labeler close: $e');
      }),
    );
    unawaited(
      _faceDetector.close().catchError((Object e) {
        debugPrint('Face detector close: $e');
      }),
    );
  }

  /// Instant metadata-based categorization for clearly defined buckets.
  /// Screenshots check runs FIRST so app-name screenshots stay in Screenshots.
  String? quickCategorize(AssetEntity asset, {String? albumName}) {
    final title = (asset.title ?? '').toLowerCase();
    final path = (asset.relativePath ?? '').toLowerCase();
    final album = (albumName ?? '').toLowerCase();

    // 1. Screen Recordings (Videos)
    if (asset.type == AssetType.video) {
      if (RegExp(
        r'screen[ _-]?(?:record|cast)|screencast',
        caseSensitive: false,
      ).hasMatch('$album $path $title')) {
        return 'Screen Recordings';
      }
    }

    // 2. Authoritative Screenshots (Checked BEFORE app-names so Screenshot_Zomato stays in Screenshots)
    final bool isScreenshotFolder =
        album.contains('screenshot') ||
        album.contains('screen shot') ||
        album.contains('screencapture') ||
        path.contains('screenshots') ||
        path.contains('screen_shot');
    final bool isScreenshotTitle =
        title.startsWith('screenshot') ||
        title.startsWith('screen_shot') ||
        title.contains('screenshot_') ||
        title.contains('scrn_') ||
        title.contains('s_shot') ||
        title.startsWith('screen_');

    if (asset.type == AssetType.image &&
        (isScreenshotFolder || isScreenshotTitle)) {
      return 'Screenshots';
    }

    // 3. Authoritative Social Media / Messaging bucket or title tags
    if (album.contains('whatsapp') ||
        path.contains('whatsapp') ||
        album.contains('telegram') ||
        path.contains('telegram') ||
        album.contains('snapchat') ||
        path.contains('snapchat') ||
        album.contains('instagram') ||
        path.contains('instagram') ||
        album.contains('facebook') ||
        path.contains('facebook') ||
        album.contains('messenger') ||
        path.contains('messenger') ||
        album.contains('signal') ||
        path.contains('signal') ||
        album.contains('twitter') ||
        path.contains('twitter') ||
        album.contains('threads') ||
        path.contains('threads') ||
        album.contains('discord') ||
        path.contains('discord')) {
      return 'Social & WhatsApp';
    }
    if (RegExp(r'(?:^|[-_])wa\d', caseSensitive: false).hasMatch(title) ||
        title.contains('tg_') ||
        title.startsWith('fb_img') ||
        title.startsWith('instagram_')) {
      return 'Social & WhatsApp';
    }

    // 4. Authoritative Downloads / Memes bucket
    if (album.contains('download') ||
        path.contains('download') ||
        album.contains('reddit') ||
        path.contains('reddit') ||
        album.contains('9gag') ||
        path.contains('9gag') ||
        album.contains('pinterest') ||
        path.contains('pinterest') ||
        album.contains('meme') ||
        path.contains('meme')) {
      return 'Downloads';
    }

    if (asset.type == AssetType.video) return 'Videos';

    // 5. Authoritative Document scanners bucket
    if (album.contains('camscanner') ||
        album.contains('adobe scan') ||
        album.contains('documents') ||
        path.contains('camscanner') ||
        path.contains('adobescan') ||
        album.contains('scanner') ||
        album.contains('receipt') ||
        album.contains('invoice')) {
      if (album.contains('receipt') || album.contains('invoice')) {
        return 'Bills & Finance';
      }
      return 'Documents & IDs';
    }

    // 6. Food & Dining album hints
    if (album.contains('food') ||
        album.contains('recipe') ||
        album.contains('restaurant') ||
        album.contains('cooking')) {
      return 'Food & Dining';
    }

    // 7. Explicit Portraits & Selfies album hints
    if (album.contains('selfie') ||
        album.contains('portrait') ||
        album.contains('portraits') ||
        album.contains('front camera')) {
      return 'Personal & Portraits';
    }

    for (final entry in contentLabels.entries) {
      final words = entry.value.map(RegExp.escape).join('|');
      if (RegExp(
        r'(?:^|[/ _-])(?:' + words + r')(?:s)?(?:$|[/ _-])',
        caseSensitive: false,
      ).hasMatch('$album $path')) {
        return entry.key;
      }
    }

    // Return null for ambiguous or Camera roll photos so they proceed to visual ML analysis
    return null;
  }

  static bool needsTextFromName(AssetEntity asset) => RegExp(
    r'\b(receipt|invoice|payment|transaction|aadhaar|passport|pancard)\b',
    caseSensitive: false,
  ).hasMatch((asset.title ?? '').replaceAll('_', ' '));

  String categoryFromNative(
    AssetEntity asset,
    Map<String, dynamic> row, {
    String? albumName,
  }) {
    final evidence = (row['labels'] as Map? ?? {}).map(
      (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
    );
    final category = classifyEvidence(
      evidence,
      text: row['text'] as String? ?? '',
    );
    return category == 'Photo Library'
        ? quickCategorize(asset, albumName: albumName) ?? category
        : category;
  }

  Future<Map<String, Map<String, dynamic>>> analyzeMediaBatch(
    List<Map<String, dynamic>> items,
  ) async {
    final raw = await _native
        .invokeListMethod<dynamic>('analyzeBatch', {'items': items})
        .timeout(const Duration(seconds: 120));
    return {
      for (final value in raw ?? [])
        (value as Map)['id'] as String: Map<String, dynamic>.from(value),
    };
  }

  static const _native = MethodChannel('com.yousful.snapsweep/classifier');

  Future<Map<String, String>> categorizeBatch(
    List<AssetEntity> assets, {
    Map<String, String> albums = const {},
  }) async {
    if (assets.length > 8) {
      throw ArgumentError('At most eight images per batch');
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return {
        for (final asset in assets)
          asset.id: await categorizeWithML(asset, albumName: albums[asset.id]),
      };
    }
    final raw = await _native
        .invokeListMethod<dynamic>('analyzeBatch', {
          'items': [
            for (final asset in assets)
              {'id': asset.id, 'readText': needsTextFromName(asset)},
          ],
        })
        .timeout(const Duration(seconds: 100));
    final results = <String, String>{};
    final byId = {for (final asset in assets) asset.id: asset};
    for (final value in raw ?? []) {
      final row = Map<String, dynamic>.from(value as Map);
      final asset = byId[row['id']];
      if (asset == null || row['ok'] != true) continue;
      final evidence = (row['labels'] as Map).map(
        (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
      );
      final category = classifyEvidence(
        evidence,
        text: row['text'] as String? ?? '',
      );
      results[asset.id] = category == 'Photo Library'
          ? quickCategorize(asset, albumName: albums[asset.id]) ?? category
          : category;
    }
    return results;
  }

  /// Advanced ML Content Classifier with Multi-Signal Voting Engine.
  /// Implements real ML Kit Face Detection, 1024px thumbnail OCR, and multi-signal scoring.
  Future<String> categorizeWithML(
    AssetEntity asset, {
    String? albumName,
  }) async {
    final quick = quickCategorize(asset, albumName: albumName);
    if (quick != null && !sourceCategories.contains(quick)) return quick;

    // Do not classify a video's thumbnail as the entire video's content.
    if (asset.type != AssetType.image) return fallbackCategory(asset);

    File? tempFile;
    File? ocrTempFile;
    try {
      // 1. Fetch 360px thumbnail for fast visual labeling and face detection
      Uint8List? thumbBytes;
      try {
        thumbBytes = await asset
            .thumbnailDataWithSize(const ThumbnailSize.square(256))
            .timeout(const Duration(seconds: 6));
      } catch (_) {}

      File? file;
      if (thumbBytes != null && thumbBytes.isNotEmpty) {
        final tempDir = Directory.systemTemp;
        tempFile = File(
          '${tempDir.path}/snapsweep_ml_${asset.id.hashCode}_${DateTime.now().microsecondsSinceEpoch}.jpg',
        );
        await tempFile.writeAsBytes(thumbBytes, flush: false);
        file = tempFile;
      } else {
        file = await asset.file;
      }

      if (file == null || !await file.exists()) {
        return fallbackCategory(asset);
      }

      final inputImage = InputImage.fromFile(file);

      // Signal 2: On-device Image Labeling at >= 0.40 confidence threshold
      final labels = await _imageLabeler
          .processImage(inputImage)
          .timeout(const Duration(seconds: 10));
      final evidence = <String, double>{
        for (final label in labels) label.label.toLowerCase(): label.confidence,
      };
      final hasTextHint = labels.any(
        (label) =>
            label.confidence >= 0.6 &&
            _docLabels.contains(label.label.toLowerCase()),
      );
      bool hasFace = false;
      String recognized = '';

      // Signal 1: Real ML Kit Face Detection on the 360x360 thumbnail
      // Any detected face with width >= 25 in the 360px thumbnail is a genuine person/portrait
      final needsFaces = labels.any(
        (label) =>
            label.confidence >= 0.55 &&
            ({
              ..._personLabels,
              'smile',
              'face',
            }).contains(label.label.toLowerCase()),
      );
      if (needsFaces) {
        try {
          final faces = await _faceDetector
              .processImage(inputImage)
              .timeout(const Duration(seconds: 10));
          if (faces.isNotEmpty) {
            bool hasValidFace = false;
            for (final face in faces) {
              if (face.boundingBox.width >= 25 &&
                  face.boundingBox.height >= 25) {
                hasValidFace = true;
                break;
              }
            }
            if (hasValidFace || faces.length >= 2) {
              hasFace = true;
            }
          }
        } catch (_) {}
      }

      // Signal 3: High-Resolution (1024px) OCR for Documents & Receipts
      final bool needsOcr = hasTextHint;
      if (needsOcr) {
        try {
          Uint8List? ocrBytes;
          try {
            ocrBytes = await asset
                .thumbnailDataWithSize(const ThumbnailSize.square(768))
                .timeout(const Duration(seconds: 6));
          } catch (_) {}

          File? ocrFile;
          if (ocrBytes != null && ocrBytes.isNotEmpty) {
            final tempDir = Directory.systemTemp;
            ocrTempFile = File(
              '${tempDir.path}/snapsweep_ocr_${asset.id.hashCode}_${DateTime.now().microsecondsSinceEpoch}.jpg',
            );
            await ocrTempFile.writeAsBytes(ocrBytes, flush: false);
            ocrFile = ocrTempFile;
          } else {
            ocrFile = file;
          }

          if (await ocrFile.exists()) {
            final ocrImage = InputImage.fromFile(ocrFile);
            final recognizedText = await _textRecognizer
                .processImage(ocrImage)
                .timeout(const Duration(seconds: 10));
            recognized = recognizedText.text;
          }
        } catch (error) {
          debugPrint('OCR unavailable; keeping visual evidence: $error');
        }
      }
      return classifyEvidence(evidence, text: recognized, hasFace: hasFace);
    } catch (e) {
      debugPrint('[Categorization ML Error] $e');
      return fallbackCategory(asset);
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
