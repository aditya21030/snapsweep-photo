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
  final _imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.3));

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

  static const List<String> _financeKeywords = [
    'gpay', 'paytm', 'phonepe', 'bhim', 'cred', 'yono', 'paypal', 'payment', 'transfer',
    'upi', 'credit', 'debit', 'balance', 'transaction', 'paid', 'wallet', 'rupees', 'rs.',
    'invoice', 'bill', 'receipt', 'tax', 'gst', 'bank', 'hdfc', 'sbi', 'icici', 'axis',
    'kotak', 'pnb', 'neft', 'imps', 'order', 'booking', 'ticket', 'razorpay', 'stripe',
    'bharatpe', 'statement', 'passbook', 'cheque', 'amazon', 'flipkart', 'ola', 'uber',
    'irctc', 'makemytrip', 'swiggy', 'zomato'
  ];

  static const List<String> _docKeywords = [
    'aadhaar', 'aadhar', 'pan card', 'pan_', 'pancard', 'driving license', 'license',
    'passport', 'voter id', 'voter', 'identity', 'id card', 'id_card', 'certificate',
    'resume', 'cv', 'marksheet', 'admit card', 'hall ticket', 'degree', 'diploma',
    'contract', 'agreement', 'salary slip', 'salary', 'form 16', 'prescription',
    'pdf', 'doc', 'camscanner', 'adobe scan', 'scanner', 'notes', 'textbook', 'report'
  ];

  static const List<String> _foodKeywords = [
    'swiggy', 'zomato', 'blinkit', 'zepto', 'instamart', 'dominos', 'kfc', 'mcdonalds',
    'starbucks', 'burger', 'pizza', 'biryani', 'food', 'restaurant', 'meal', 'dish',
    'recipe', 'grocery', 'cafe', 'coffee', 'snack', 'dessert', 'baking', 'cooking'
  ];

  static const List<String> _socialKeywords = [
    'whatsapp', 'wa0', 'wa1', 'wa2', '_wa', 'telegram', 'tg_', 'instagram', 'insta',
    'messenger', 'snapchat', 'snap_', 'discord', 'signal', 'facebook', 'fb_', 'twitter',
    'x_', 'pinterest', 'tiktok', 'viber', 'wechat', 'line', 'threads'
  ];

  static const List<String> _downloadKeywords = [
    'download', 'downloads', 'browser', 'chrome', 'firefox', 'opera', 'edge', 'brave',
    'ucbrowser', 'meme', 'reddit', '9gag', 'sticker', 'gif', 'webp', 'saved_image'
  ];

  static const List<String> _cameraKeywords = [
    'camera', 'dcim', '100and', '100media', 'img_', 'pxl_', 'dsc_', 'sam_', 'hdr_',
    'raw_', 'camerakit', 'portrait', 'mvimg_'
  ];

  void dispose() {
    _textRecognizer.close();
    _imageLabeler.close();
  }

  /// Fast metadata & heuristic categorization (< 0.05ms per item with 0 lag)
  String quickCategorize(AssetEntity asset) {
    final title = (asset.title ?? '').toLowerCase();
    final path = (asset.relativePath ?? '').toLowerCase();
    final combined = '$title $path';

    // 0. Screen Recordings (Videos)
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
      return 'Others';
    }

    // 1. Bills & Finance (Priority over general screenshots)
    for (final kw in _financeKeywords) {
      if (combined.contains(kw)) return 'Bills & Finance';
    }

    // 2. Documents & IDs (Priority over general screenshots)
    for (final kw in _docKeywords) {
      if (combined.contains(kw)) return 'Documents & IDs';
    }

    // 3. Screenshots
    if (combined.contains('screen') || combined.contains('capture') || combined.contains('screenshot') ||
        combined.contains('scrn_') || combined.contains('snapshot')) {
      return 'Screenshots';
    }

    // Check screen aspect ratio heuristics for screenshots (e.g. 19:9, 20:9, 21:9 phones)
    if (asset.width > 0 && asset.height > 0) {
      final longer = asset.width > asset.height ? asset.width : asset.height;
      final shorter = asset.width < asset.height ? asset.width : asset.height;
      final ratio = longer / shorter;
      if (ratio >= 1.95 && ratio <= 2.35) {
        // High likelihood of mobile screenshot if not in camera directory
        if (!combined.contains('dcim') && !combined.contains('camera')) {
          return 'Screenshots';
        }
      }
    }

    // 4. WhatsApp & Social Media
    for (final kw in _socialKeywords) {
      if (combined.contains(kw)) return 'Social & WhatsApp';
    }

    // 5. Downloads & Memes
    for (final kw in _downloadKeywords) {
      if (combined.contains(kw)) return 'Memes & Downloads';
    }

    // 6. Food & Dining
    for (final kw in _foodKeywords) {
      if (combined.contains(kw)) return 'Food & Dining';
    }

    // 7. Camera photos / Portraits (DCIM, Camera Roll)
    for (final kw in _cameraKeywords) {
      if (combined.contains(kw)) return 'Personal & Portraits';
    }

    // 8. General Aspect Ratio / Resolution Fallbacks (Prevent dumping into "Others")
    if (asset.width > 0 && asset.height > 0) {
      final longer = asset.width > asset.height ? asset.width : asset.height;
      final shorter = asset.width < asset.height ? asset.width : asset.height;
      final ratio = longer / shorter;

      // Typical camera photo ratios (4:3 is ~1.33, 16:9 is ~1.78)
      if ((ratio >= 1.25 && ratio <= 1.45) || (ratio >= 1.70 && ratio <= 1.85)) {
        if (longer >= 1920) {
          return 'Personal & Portraits';
        }
      }

      // Square (1:1) format is overwhelmingly memes, stickers, or social downloads
      if (ratio >= 0.95 && ratio <= 1.05) {
        return 'Memes & Downloads';
      }
    }

    return 'Others';
  }

  /// Deep ML-assisted categorization for ambiguous items
  Future<CategoryResult> categorize(AssetEntity asset) async {
    final fastCat = quickCategorize(asset);
    if (fastCat != 'Others') {
      return CategoryResult(fastCat, debugInfo: 'Fast Heuristic Match');
    }

    try {
      final file = await asset.file;
      if (file == null || !await file.exists()) {
        return CategoryResult('Others');
      }

      final inputImage = InputImage.fromFile(file);

      // OCR check for receipts & documents
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final text = recognizedText.text.toLowerCase();

      if (text.length > 10) {
        for (final kw in _financeKeywords) {
          if (text.contains(kw)) return CategoryResult('Bills & Finance', debugInfo: 'OCR Finance: $kw');
        }
        for (final kw in _docKeywords) {
          if (text.contains(kw)) return CategoryResult('Documents & IDs', debugInfo: 'OCR Doc: $kw');
        }
        for (final kw in _foodKeywords) {
          if (text.contains(kw)) return CategoryResult('Food & Dining', debugInfo: 'OCR Food: $kw');
        }
      }

      // Labeling check
      final labels = await _imageLabeler.processImage(inputImage);
      for (final label in labels) {
        final labelText = label.label.toLowerCase();
        if (labelText.contains('food') || labelText.contains('dish') || labelText.contains('meal') || labelText.contains('cuisine')) {
          return CategoryResult('Food & Dining', debugInfo: 'Label: $labelText');
        }
        if (labelText.contains('person') || labelText.contains('face') || labelText.contains('people') || labelText.contains('smile')) {
          return CategoryResult('Personal & Portraits', debugInfo: 'Label: $labelText');
        }
        if (labelText.contains('document') || labelText.contains('paper') || labelText.contains('text') || labelText.contains('page')) {
          return CategoryResult('Documents & IDs', debugInfo: 'Label: $labelText');
        }
      }

      // If camera resolution, default to Personal & Portraits
      if (asset.width * asset.height > 2000000) {
        return CategoryResult('Personal & Portraits', debugInfo: 'High-Res Fallback');
      }

      return CategoryResult('Others');
    } catch (e) {
      return CategoryResult('Others', debugInfo: 'Error: $e');
    }
  }
}
