import 'dart:math';
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
    'rs ', 'inr', 'invoice', 'bill', 'receipt', 'tax', 'gst', 'bank', 'hdfc', 'sbi',
    'icici', 'axis', 'kotak', 'pnb', 'neft', 'imps', 'order', 'booking', 'ticket',
    'razorpay', 'stripe', 'bharatpe', 'statement', 'passbook', 'cheque', 'amazon',
    'flipkart', 'ola', 'uber', 'irctc', 'makemytrip', 'swiggy', 'zomato'
  ];

  static const List<String> _docKeywords = [
    'aadhaar', 'aadhar', 'pan card', 'pan_', 'pancard', 'driving license', 'license',
    'dl_', 'passport', 'voter id', 'voter', 'identity', 'id card', 'id_card', 'certificate',
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
    'whatsapp', 'wa0', 'wa1', 'wa2', '_wa', '-wa', 'telegram', 'tg_', 'instagram', 'insta',
    'messenger', 'snapchat', 'snap_', 'discord', 'signal', 'facebook', 'fb_', 'twitter',
    'x_', 'pinterest', 'tiktok', 'viber', 'wechat', 'line', 'threads'
  ];

  static const List<String> _downloadKeywords = [
    'download', 'downloads', 'browser', 'chrome', 'firefox', 'opera', 'edge', 'brave',
    'ucbrowser', 'meme', 'reddit', '9gag', 'sticker', 'gif', 'webp', 'saved_image'
  ];

  static const List<String> _cameraKeywords = [
    'camera', 'dcim', '100and', '100media', 'img_', 'pxl_', 'dsc_', 'sam_', 'hdr_',
    'raw_', 'camerakit', 'portrait', 'mvimg_', 'selfie'
  ];

  void dispose() {
    _textRecognizer.close();
    _imageLabeler.close();
  }

  /// Authoritative multi-tier categorization using Android bucket names, path, title, and heuristics
  String quickCategorize(AssetEntity asset, {String? albumName}) {
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
      if (combined.contains('camera') || combined.contains('dcim')) {
        return 'Personal & Portraits';
      }
      return 'Screen Recordings';
    }

    // 2. High-priority content checks: Bills & Finance (regardless of folder)
    for (final kw in _financeKeywords) {
      if (combined.contains(kw)) return 'Bills & Finance';
    }

    // 3. High-priority content checks: Documents & IDs (regardless of folder)
    for (final kw in _docKeywords) {
      if (combined.contains(kw)) return 'Documents & IDs';
    }

    // 4. Food & Dining
    for (final kw in _foodKeywords) {
      if (combined.contains(kw)) return 'Food & Dining';
    }

    // 5. Authoritative Screenshots bucket / title check
    if (album.contains('screenshot') || album.contains('screen shot') || album.contains('capture') ||
        path.contains('screenshot') || path.contains('capture') ||
        title.contains('screenshot') || title.contains('screen_shot') || title.contains('screen shot') ||
        title.contains('scrn_') || title.contains('s_shot') || title.startsWith('screen_')) {
      return 'Screenshots';
    }

    // 6. Authoritative Social Media / Messaging bucket check
    if (album.contains('whatsapp') || album.contains('telegram') || album.contains('instagram') ||
        album.contains('snapchat') || album.contains('facebook') || album.contains('messenger') ||
        album.contains('discord') || album.contains('signal') || album.contains('twitter') ||
        album.contains('threads') || album.contains('pinterest')) {
      return 'Social & WhatsApp';
    }

    // Path or file pattern for WhatsApp / Social
    for (final kw in _socialKeywords) {
      if (combined.contains(kw)) return 'Social & WhatsApp';
    }

    // 7. Authoritative Downloads / Memes bucket check
    if (album.contains('download') || album.contains('browser') || album.contains('chrome') ||
        album.contains('opera') || album.contains('edge') || album.contains('firefox') ||
        album.contains('meme') || album.contains('reddit') || album.contains('9gag')) {
      return 'Memes & Downloads';
    }

    for (final kw in _downloadKeywords) {
      if (combined.contains(kw)) return 'Memes & Downloads';
    }

    // 8. Authoritative Camera Roll / Portraits bucket check
    if (album.contains('camera') || album.contains('dcim') || album.contains('100and') ||
        album.contains('portrait') || album.contains('selfie') || album.contains('camerakit')) {
      return 'Personal & Portraits';
    }

    for (final kw in _cameraKeywords) {
      if (combined.contains(kw)) return 'Personal & Portraits';
    }

    // 9. Dimension & Aspect Ratio Heuristic Fallbacks
    if (asset.width > 0 && asset.height > 0) {
      final longer = max(asset.width, asset.height);
      final shorter = min(asset.width, asset.height);
      final ratio = longer / shorter;

      // Phone display aspect ratio (19:9, 19.5:9, 20:9, 21:9) -> Screenshots
      if (ratio >= 1.92 && ratio <= 2.38) {
        return 'Screenshots';
      }

      // 1:1 Square images are overwhelmingly memes, stickers, or social downloads
      if (ratio >= 0.95 && ratio <= 1.05) {
        return 'Memes & Downloads';
      }

      // Standard photo ratios (4:3, 16:9) with camera resolution
      if ((ratio >= 1.25 && ratio <= 1.45) || (ratio >= 1.70 && ratio <= 1.85)) {
        if (longer >= 1920) {
          return 'Personal & Portraits';
        }
      }
    }

    // 10. Intelligent High-Res Fallback
    if (asset.width * asset.height > 2000000) {
      return 'Personal & Portraits';
    }

    return 'Others';
  }

  /// Deep ML-assisted categorization for ambiguous items
  Future<CategoryResult> categorize(AssetEntity asset, {String? albumName}) async {
    final fastCat = quickCategorize(asset, albumName: albumName);
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

      if (text.length > 8) {
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

      if (asset.width * asset.height > 2000000) {
        return CategoryResult('Personal & Portraits', debugInfo: 'High-Res Fallback');
      }

      return CategoryResult('Others');
    } catch (e) {
      return CategoryResult('Others', debugInfo: 'Error: $e');
    }
  }
}
