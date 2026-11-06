import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'billing_service.dart';

class CompletionAdPolicy {
  CompletionAdPolicy({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  DateTime? _lastShown;
  bool _usedThisSession = false;
  void restoreCooldown(DateTime? lastShown) {
    _lastShown = lastShown;
  }

  bool consume({
    required bool premium,
    required bool ready,
    required bool allowed,
  }) {
    if (premium || !ready || !allowed || _usedThisSession) return false;
    final now = _clock();
    if (_lastShown != null &&
        now.difference(_lastShown!) < const Duration(minutes: 3)) {
      return false;
    }
    _usedThisSession = true;
    _lastShown = now;
    return true;
  }
}

class AdService {
  static const productionInterstitial = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-9787505657189806/2924077899',
  );
  static const productionNative = String.fromEnvironment(
    'ADMOB_NATIVE_AD_UNIT_ID',
  );
  static String get interstitialAdUnitId => kReleaseMode
      ? productionInterstitial
      : 'ca-app-pub-3940256099942544/1033173712';
  static String get nativeAdUnitId => kReleaseMode
      ? productionNative
      : 'ca-app-pub-3940256099942544/2247696110';
  static final adsAllowed = ValueNotifier<bool>(false);
  static final privacyOptionsRequired = ValueNotifier<bool>(false);
  static final _policy = CompletionAdPolicy();
  static InterstitialAd? _interstitial;
  static Future<void>? _initializing;
  static bool _initialized = false;
  static bool _loading = false;
  static bool _listening = false;
  static bool _showing = false;
  static int _requestGeneration = 0;

  static Future<void> initialize() =>
      _initializing ??= _initialize().whenComplete(() => _initializing = null);
  static Future<void> _initialize() async {
    if (!_listening) {
      _listening = true;
      BillingService.isPremiumNotifier.addListener(() {
        if (BillingService.isPremium) {
          _requestGeneration++;
          _loading = false;
          adsAllowed.value = false;
          _interstitial?.dispose();
          _interstitial = null;
        } else {
          unawaited(initialize());
        }
      });
    }
    if (BillingService.isPremium ||
        (kReleaseMode &&
            productionInterstitial.isEmpty &&
            productionNative.isEmpty)) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt('last_completion_ad_ms');
      if (last != null) {
        _policy.restoreCooldown(DateTime.fromMillisecondsSinceEpoch(last));
      }
      final consent = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
            await _applyConsent();
          } catch (error) {
            debugPrint('[Consent form] $error');
          } finally {
            if (!consent.isCompleted) consent.complete();
          }
        },
        (_) {
          if (!consent.isCompleted) consent.complete();
        },
      );
      await consent.future.timeout(const Duration(seconds: 30));
      await _applyConsent();
    } catch (error) {
      debugPrint('[Ads consent] $error');
    }
  }

  static Future<void> _applyConsent() async {
    privacyOptionsRequired.value =
        await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
    final allowed =
        !BillingService.isPremium &&
        await ConsentInformation.instance.canRequestAds();
    if (!allowed) {
      adsAllowed.value = false;
      _interstitial?.dispose();
      _interstitial = null;
      return;
    }
    if (!_initialized) {
      await MobileAds.instance.initialize();
      _initialized = true;
    }
    adsAllowed.value = true;
    loadInterstitialAd();
  }

  static Future<void> showPrivacyOptions() async {
    _requestGeneration++;
    _loading = false;
    adsAllowed.value = false;
    _interstitial?.dispose();
    _interstitial = null;
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) debugPrint('[Privacy options] ${error.message}');
    });
    await _applyConsent();
  }

  static void loadInterstitialAd() {
    if (!_initialized ||
        !adsAllowed.value ||
        BillingService.isPremium ||
        _loading ||
        _interstitial != null ||
        interstitialAdUnitId.isEmpty) {
      return;
    }
    _loading = true;
    final generation = _requestGeneration;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (generation != _requestGeneration) {
            ad.dispose();
            return;
          }
          _loading = false;
          if (BillingService.isPremium || !adsAllowed.value) {
            ad.dispose();
            return;
          }
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) {
          if (generation != _requestGeneration) return;
          _loading = false;
          debugPrint('[Interstitial] $error');
        },
      ),
    );
  }

  /// Called only after the user presses Continue on a completed-operation result.
  static Future<void> showCompletionAd() async {
    if (_showing ||
        !_policy.consume(
          premium: BillingService.isPremium,
          ready: _interstitial != null,
          allowed: adsAllowed.value,
        )) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_completion_ad_ms',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (error) {
      debugPrint('[Ad frequency cache] $error');
    }
    if (BillingService.isPremium ||
        !adsAllowed.value ||
        _interstitial == null) {
      return;
    }
    final ad = _interstitial!;
    _interstitial = null;
    _showing = true;
    final done = Completer<void>();
    void finish() {
      ad.dispose();
      _showing = false;
      if (!done.isCompleted) done.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => finish(),
      onAdFailedToShowFullScreenContent: (_, error) => finish(),
    );
    try {
      await ad.show();
      await done.future;
    } catch (_) {
      finish();
    }
  }
}
