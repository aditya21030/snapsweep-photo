import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:photo_manager/photo_manager.dart';

class CategoryResult {
  final String category;
  final String? debugInfo;

  CategoryResult(this.category, {this.debugInfo});
}

class CategorizationService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.35));

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

  static const List<String> _foodKeywords = [
    'food', 'recipe', 'dish', 'cooking', 'dinner', 'lunch', 'breakfast', 'snack',
    'dessert', 'cake', 'swiggy', 'zomato', 'pizza', 'burger', 'restaurant', 'cafe',
    'coffee', 'tea', 'menu', 'baking', 'cocktail', 'juice', 'meal', 'curry', 'pasta'
  ];

  static const List<String> _foodLabels = [
    'food', 'dish', 'cuisine', 'meal', 'dessert', 'snack', 'tableware', 'ingredient',
    'recipe', 'meat', 'vegetable', 'fruit', 'drink', 'beverage', 'cocktail', 'coffee',
    'tea', 'fast food', 'baked goods', 'bread', 'cake', 'pizza', 'burger', 'noodle',
    'rice', 'curry', 'salad', 'seafood', 'soup', 'plate', 'bowl', 'fork', 'spoon',
    'culinary', 'restaurant', 'pasta', 'cheese', 'ice cream', 'breakfast', 'lunch',
    'dinner', 'sandwich', 'pastry', 'cookie', 'juice', 'alcohol', 'beer', 'wine',
    'delicacy', 'platter', 'barbecue', 'buffet', 'brunch', 'confectionery', 'condiment'
  ];

  static const List<String> _personLabels = [
    'person', 'face', 'smile', 'selfie', 'portrait', 'people', 'human', 'man',
    'woman', 'girl', 'boy', 'child', 'baby', 'clothing', 'eyewear', 'sunglasses',
    'hair', 'crowd', 'friendship', 'family', 'cheering', 'facial hair', 'beard',
    'forehead', 'chin', 'neck', 'shoulder', 'gesture', 'flesh', 'head'
  ];

  static const List<String> _docLabels = [
    'document', 'paper', 'text', 'book', 'newspaper', 'letter', 'receipt',
    'invoice', 'bill', 'envelope', 'publication', 'handwriting', 'font',
    'identity document', 'passport', 'driver\'s license', 'certificate',
    'ticket', 'business card', 'label', 'sheet music', 'flyer', 'page'
  ];

  static const List<String> _memeLabels = [
    'cartoon', 'comics', 'illustration', 'animated cartoon', 'meme', 'drawing',
    'art', 'graphics', 'fiction', 'clip art', 'fictional character', 'graffiti',
    'poster'
  ];

  static const List<String> _financeKeywords = [
    'gpay', 'paytm', 'phonepe', 'bhim', 'cred', 'yono', 'paypal', 'payment', 'transfer',
    'upi', 'credit', 'debit', 'balance', 'transaction', 'paid', 'wallet', 'rupees', 'rs.',
    'rs ', 'inr', 'invoice', 'bill', 'receipt', 'tax', 'gst', 'gstin', 'bank', 'hdfc',
    'sbi', 'icici', 'axis', 'kotak', 'pnb', 'neft', 'imps', 'order', 'booking', 'ticket',
    'razorpay', 'stripe', 'bharatpe', 'statement', 'passbook', 'cheque', 'subtotal',
    'grand total', 'net payable', 'amount due', 'due date', 'billing', 'cashier',
    'merchant', 'swiggy', 'zomato', 'uber', 'ola', 'amazon', 'flipkart', 'cash receipt',
    'order id', 'txn id', 'transaction id', 'reference no', 'ref no'
  ];

  static const List<String> _docKeywords = [
    'aadhaar', 'aadhar', 'government of india', 'income tax department', 'permanent account number',
    'pan card', 'pancard', 'driving license', 'driving licence', 'union of india', 'transport department',
    'electoral photo', 'voter id', 'voter', 'election commission', 'passport', 'republic of india',
    'identity', 'id card', 'id_card', 'certificate', 'marksheet', 'admit card', 'hall ticket',
    'degree', 'diploma', 'university', 'college', 'school', 'examination', 'roll no',
    'contract', 'agreement', 'affidavit', 'salary slip', 'salary', 'form 16', 'prescription',
    'pdf', 'doc', 'camscanner', 'adobe scan', 'scanner', 'notes', 'textbook', 'report',
    'date of birth', 'dob:', 'father\'s name', 'enrollment', 'registration no', 'declaration'
  ];

  static const List<String> _socialKeywords = [
    'whatsapp', 'wa0', 'wa1', 'wa2', '_wa', '-wa', 'telegram', 'tg_', 'instagram', 'insta',
    'messenger', 'snapchat', 'snap_', 'discord', 'signal', 'facebook', 'fb_', 'twitter',
    'x_', 'pinterest', 'tiktok', 'viber', 'wechat', 'line', 'threads', 'gbwhatsapp',
    'fmwhatsapp', 'inshot', 'capcut', 'vsco'
  ];

  static const List<String> _downloadKeywords = [
    'download', 'downloads', 'browser', 'chrome', 'firefox', 'opera', 'edge', 'brave',
    'ucbrowser', 'meme', 'reddit', '9gag', 'sticker', 'gif', 'webp', 'saved_image'
  ];

  static final RegExp _currencyRegex = RegExp(r'(?:₹|\$|€|£|rs\.?|inr)\s*\d+(?:[.,]\d{2})?', caseSensitive: false);
  static final RegExp _transactionRegex = RegExp(r'\b(?:upi\s*ref|txn\s*id|transaction\s*id|invoice\s*no|gstin|subtotal|grand\s*total|net\s*payable|amount\s*paid|paid\s*to|transfer\s*successful)\b', caseSensitive: false);
  static final RegExp _aadhaarRegex = RegExp(r'\b\d{4}\s\d{4}\s\d{4}\b');
  static final RegExp _panRegex = RegExp(r'\b[A-Z]{5}[0-9]{4}[A-Z]\b', caseSensitive: false);
  static final RegExp _dlRegex = RegExp(r'\b[A-Z]{2}[-\s]?\d{2}[-\s]?\d{4}[-\s]?\d{7}\b', caseSensitive: false);
  static final RegExp _memeSlangRegex = RegExp(r'\b(?:when you|me when|nobody:|pov|relatable|literally|bruh|bro|tbh|lmao|lol|caption this)\b', caseSensitive: false);

  void dispose() {
    _textRecognizer.close();
    _imageLabeler.close();
  }

  /// Instant metadata-based categorization for clearly defined buckets (Screenshots, WhatsApp, Downloads, Videos).
  /// Returns null for ambiguous or Camera roll photos that require visual ML analysis.
  String? quickCategorize(AssetEntity asset, {String? albumName}) {
    final title = (asset.title ?? '').toLowerCase();
    final path = (asset.relativePath ?? '').toLowerCase();
    final album = (albumName ?? '').toLowerCase();
    final combined = '$title $path $album';

    // 1. Screen Recordings (Videos)
    if (asset.type == AssetType.video) {
      if (combined.contains('screen') || combined.contains('record') || combined.contains('screencast')) {
        return 'Screen Recordings';
      }
      for (final kw in _socialKeywords) {
        if (combined.contains(kw)) return 'Social & WhatsApp';
      }
      for (final kw in _downloadKeywords) {
        if (combined.contains(kw)) return 'Memes & Downloads';
      }
      return null;
    }

    // 2. High-confidence explicit file title matches
    for (final kw in _financeKeywords) {
      if (title.contains(kw)) return 'Bills & Finance';
    }
    for (final kw in _docKeywords) {
      if (title.contains(kw)) return 'Documents & IDs';
    }

    // 3. Authoritative Screenshots bucket or title
    if (album.contains('screenshot') || album.contains('screen shot') || album.contains('capture') ||
        path.contains('screenshot') || path.contains('capture') ||
        title.contains('screenshot') || title.contains('screen_shot') || title.contains('screen shot') ||
        title.contains('scrn_') || title.contains('s_shot') || title.startsWith('screen_')) {
      return 'Screenshots';
    }

    // 4. Modern phone display aspect ratio (19:9 to 21.5:9) with PNG or screenshot dimensions
    if (asset.width > 0 && asset.height > 0) {
      final longer = max(asset.width, asset.height);
      final shorter = min(asset.width, asset.height);
      final ratio = longer / shorter;
      if (ratio >= 1.95 && ratio <= 2.35 && (title.endsWith('.png') || path.contains('dcim/screenshots'))) {
        return 'Screenshots';
      }
    }

    // 5. Authoritative Social Media / WhatsApp bucket or title
    if (album.contains('whatsapp') || album.contains('telegram') || album.contains('instagram') ||
        album.contains('snapchat') || album.contains('facebook') || album.contains('messenger') ||
        album.contains('discord') || album.contains('signal') || album.contains('twitter') ||
        album.contains('threads') || album.contains('pinterest')) {
      return 'Social & WhatsApp';
    }
    for (final kw in _socialKeywords) {
      if (title.contains(kw)) return 'Social & WhatsApp';
    }

    // 6. Authoritative Downloads bucket or title
    if (album.contains('download') || album.contains('browser') || album.contains('chrome') ||
        album.contains('opera') || album.contains('edge') || album.contains('firefox') ||
        album.contains('meme') || album.contains('reddit') || album.contains('9gag') || album.contains('sticker')) {
      return 'Memes & Downloads';
    }
    for (final kw in _downloadKeywords) {
      if (title.contains(kw)) return 'Memes & Downloads';
    }

    // 7. Food & Dining keyword match in album or title
    for (final kw in _foodKeywords) {
      if (combined.contains(kw)) return 'Food & Dining';
    }

    // 8. Explicit Portraits & Selfies album or title matches
    if (album.contains('selfie') || album.contains('portrait') || album.contains('portraits') ||
        title.contains('selfie') || title.contains('portrait') || title.contains('face')) {
      return 'Personal & Portraits';
    }

    return null;
  }

  /// Advanced ML Kit Content Classifier inspecting visual objects and printed text
  Future<String> categorizeWithML(AssetEntity asset, {String? albumName}) async {
    final quick = quickCategorize(asset, albumName: albumName);
    if (quick != null) return quick;

    File? tempFile;
    try {
      // Use downscaled 360x360 thumbnail for ML to avoid decoding 40MB raw photos
      Uint8List? thumbBytes;
      try {
        thumbBytes = await asset.thumbnailDataWithSize(const ThumbnailSize.square(360));
      } catch (_) {}

      File? file;
      if (thumbBytes != null && thumbBytes.isNotEmpty) {
        final tempDir = Directory.systemTemp;
        tempFile = File('${tempDir.path}/snapsweep_ml_thumb_${asset.id.hashCode}_${DateTime.now().microsecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(thumbBytes, flush: true);
        file = tempFile;
      } else {
        file = await asset.file;
      }

      if (file == null || !await file.exists()) {
        return _fallbackCategory(asset, albumName: albumName);
      }

      final inputImage = InputImage.fromFile(file);

      // 1. Run on-device Image Labeling
      final labels = await _imageLabeler.processImage(inputImage);

      bool isFood = false;
      bool isPerson = false;
      bool isDocVisual = false;
      bool isMeme = false;

      for (final l in labels) {
        final label = l.label.toLowerCase();
        final conf = l.confidence;
        if (conf < 0.35) continue;

        if (_foodLabels.any((k) => label.contains(k))) {
          isFood = true;
          break; // High confidence food detection
        }
        if (_personLabels.any((k) => label.contains(k))) {
          isPerson = true;
        }
        if (_docLabels.any((k) => label.contains(k))) {
          isDocVisual = true;
        }
        if (_memeLabels.any((k) => label.contains(k))) {
          isMeme = true;
        }
      }

      if (isFood) return 'Food & Dining';

      // 2. If visual hints indicate document/paper/receipt/text, run OCR
      if (isDocVisual) {
        final recognizedText = await _textRecognizer.processImage(inputImage);
        final ocr = recognizedText.text.toLowerCase();
        if (ocr.length >= 6) {
          if (_currencyRegex.hasMatch(ocr) || _transactionRegex.hasMatch(ocr) || _financeKeywords.any((kw) => ocr.contains(kw))) {
            return 'Bills & Finance';
          }
          if (_aadhaarRegex.hasMatch(ocr) || _panRegex.hasMatch(ocr) || _dlRegex.hasMatch(ocr) || _docKeywords.any((kw) => ocr.contains(kw))) {
            return 'Documents & IDs';
          }
          if (ocr.length <= 160 && _memeSlangRegex.hasMatch(ocr)) {
            return 'Memes & Downloads';
          }
          if (ocr.length > 50 || recognizedText.blocks.length >= 3) {
            return 'Documents & IDs';
          }
        }
      }

      if (isPerson) return 'Personal & Portraits';
      if (isMeme) return 'Memes & Downloads';

      // 3. Second-chance OCR if labels contain font/text/display keywords
      final hasTextHint = labels.any((l) {
        final txt = l.label.toLowerCase();
        return txt.contains('text') || txt.contains('font') || txt.contains('paper') ||
               txt.contains('receipt') || txt.contains('screenshot') || txt.contains('web page');
      });

      if (hasTextHint) {
        final recognizedText = await _textRecognizer.processImage(inputImage);
        final ocr = recognizedText.text.toLowerCase();
        if (ocr.length >= 6) {
          if (_currencyRegex.hasMatch(ocr) || _transactionRegex.hasMatch(ocr) || _financeKeywords.any((kw) => ocr.contains(kw))) {
            return 'Bills & Finance';
          }
          if (_aadhaarRegex.hasMatch(ocr) || _panRegex.hasMatch(ocr) || _dlRegex.hasMatch(ocr) || _docKeywords.any((kw) => ocr.contains(kw))) {
            return 'Documents & IDs';
          }
          if (ocr.length <= 160 && _memeSlangRegex.hasMatch(ocr)) {
            return 'Memes & Downloads';
          }
          if (ocr.length > 40) {
            return 'Documents & IDs';
          }
        }
      }

      return _fallbackCategory(asset, albumName: albumName);
    } catch (e) {
      debugPrint('[Categorization ML Error] $e');
      return _fallbackCategory(asset, albumName: albumName);
    } finally {
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }
    }
  }

  String _fallbackCategory(AssetEntity asset, {String? albumName}) {
    if (asset.type == AssetType.video) return 'Screen Recordings';

    if (asset.width > 0 && asset.height > 0) {
      final longer = max(asset.width, asset.height);
      final shorter = min(asset.width, asset.height);
      final ratio = longer / shorter;

      // 1:1 Square images
      if (ratio >= 0.95 && ratio <= 1.05) return 'Memes & Downloads';

      // Smartphone screenshot ratio
      if (ratio >= 1.95 && ratio <= 2.35) return 'Screenshots';

      return 'Others';
    }

    return 'Others';
  }
}
