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
  final _imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.3));

  static const List<String> availableCategories = [
    'Screenshots',
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
    'kotak', 'pnb', 'neft', 'imps', 'order', 'booking', 'ticket'
  ];

  static const List<String> _docKeywords = [
    'aadhaar', 'pan card', 'driving license', 'passport', 'voter id', 'certificate',
    'resume', 'cv', 'marksheet', 'admit card', 'identity', 'id card', 'contract',
    'agreement', 'salary slip', 'form 16', 'prescription', 'pdf', 'doc'
  ];

  static const List<String> _foodKeywords = [
    'swiggy', 'zomato', 'blinkit', 'zepto', 'dominos', 'kfc', 'mcdonalds', 'burger',
    'pizza', 'biryani', 'food', 'restaurant', 'meal', 'dish', 'recipe', 'grocery'
  ];

  void dispose() {
    _textRecognizer.close();
    _imageLabeler.close();
  }

  /// Fast metadata & path categorization (runs in < 0.1ms per item with 0 lag)
  String quickCategorize(AssetEntity asset) {
    final title = (asset.title ?? '').toLowerCase();
    final path = (asset.relativePath ?? '').toLowerCase();

    // 1. Screenshots
    if (title.contains('screen') || title.contains('capture') || title.contains('screenshot') ||
        path.contains('screen') || path.contains('capture') || path.contains('screenshot')) {
      for (final kw in _financeKeywords) {
        if (title.contains(kw) || path.contains(kw)) return 'Bills & Finance';
      }
      for (final kw in _docKeywords) {
        if (title.contains(kw) || path.contains(kw)) return 'Documents & IDs';
      }
      return 'Screenshots';
    }

    // 2. WhatsApp & Social Media
    if (path.contains('whatsapp') || path.contains('telegram') || path.contains('instagram') ||
        path.contains('messenger') || path.contains('snapchat') || path.contains('discord') ||
        path.contains('facebook') || path.contains('twitter') || path.contains('signal')) {
      return 'Social & WhatsApp';
    }

    // 3. Downloads & Memes
    if (path.contains('download') || path.contains('browser') || path.contains('chrome')) {
      return 'Memes & Downloads';
    }

    // 4. Bills & Finance
    for (final kw in _financeKeywords) {
      if (title.contains(kw) || path.contains(kw)) return 'Bills & Finance';
    }

    // 5. Documents & IDs
    for (final kw in _docKeywords) {
      if (title.contains(kw) || path.contains(kw)) return 'Documents & IDs';
    }

    // 6. Food
    for (final kw in _foodKeywords) {
      if (title.contains(kw) || path.contains(kw)) return 'Food & Dining';
    }

    // 7. Camera photos (DCIM)
    if (path.contains('camera') || path.contains('dcim') || title.startsWith('img_')) {
      return 'Personal & Portraits';
    }

    return 'Others';
  }

  /// Deep ML-assisted categorization for ambiguous items
  Future<CategoryResult> categorize(AssetEntity asset) async {
    // Try fast categorization first
    final fastCat = quickCategorize(asset);
    if (fastCat != 'Others') {
      return CategoryResult(fastCat, debugInfo: 'Fast Metadata Match');
    }

    try {
      final file = await asset.file;
      if (file == null || !await file.exists()) {
        return CategoryResult('Others');
      }

      final inputImage = InputImage.fromFile(file);

      // OCR check
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
        if (labelText.contains('food') || labelText.contains('dish') || labelText.contains('meal')) {
          return CategoryResult('Food & Dining', debugInfo: 'Label: $labelText');
        }
        if (labelText.contains('person') || labelText.contains('face') || labelText.contains('people')) {
          return CategoryResult('Personal & Portraits', debugInfo: 'Label: $labelText');
        }
        if (labelText.contains('document') || labelText.contains('paper') || labelText.contains('text')) {
          return CategoryResult('Documents & IDs', debugInfo: 'Label: $labelText');
        }
      }

      return CategoryResult('Others');
    } catch (e) {
      debugPrint('Categorization error: $e');
      return CategoryResult('Others');
    }
  }
}
