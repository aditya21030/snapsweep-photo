import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'billing_service.dart';

class AdService {
  // Official Google AdMob Android test ad unit ID for development, production ID for release
  static const String _prodInterstitialAdUnitId = 'ca-app-pub-8510502760785545/8753913671';
  static const String _testInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';

  static String get interstitialAdUnitId =>
      kDebugMode ? _testInterstitialAdUnitId : _prodInterstitialAdUnitId;

  static InterstitialAd? _interstitialAd;
  static bool _isAdLoading = false;

  /// Initializes MobileAds safely
  static Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      loadInterstitialAd();
    } catch (e) {
      debugPrint('AdService initialization failed: $e');
    }
  }

  /// Loads an interstitial ad.
  static void loadInterstitialAd() {
    if (_isAdLoading || _interstitialAd != null) return;

    _isAdLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('InterstitialAd loaded.');
          _interstitialAd = ad;
          _isAdLoading = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('InterstitialAd failed to load: $error');
          _interstitialAd = null;
          _isAdLoading = false;
        },
      ),
    );
  }

  /// Shows the interstitial ad if it's loaded.
  static void showInterstitialAd({VoidCallback? onAdDismissed}) {
    // If user has purchased ad-free / premium via Google Play, skip ads
    if (BillingService.isPremium) {
      onAdDismissed?.call();
      return;
    }

    if (_interstitialAd == null) {
      onAdDismissed?.call();
      loadInterstitialAd(); // Load for next time
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('Ad dismissed.');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Preload next one
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Ad failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onAdDismissed?.call();
      },
    );

    _interstitialAd!.show();
  }
}
