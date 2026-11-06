import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BillingStage {
  idle,
  loading,
  ready,
  opening,
  pending,
  restoring,
  success,
  cancelled,
  error,
  unavailable,
}

@immutable
class BillingState {
  const BillingState(this.stage, [this.message = '']);
  final BillingStage stage;
  final String message;
  bool get busy => {
    BillingStage.loading,
    BillingStage.opening,
    BillingStage.pending,
    BillingStage.restoring,
  }.contains(stage);
}

class BillingService {
  static final state = ValueNotifier<BillingState>(
    const BillingState(BillingStage.idle),
  );
  static Future<void>? _initializing;
  static bool _initialized = false;
  static bool _purchasing = false;
  static Future<void> _updates = Future.value();
  static ProductDetails? get removeAdsProduct {
    for (final product in products) {
      if (product.id == removeAdsId) return product;
    }
    return null;
  }

  static void _status(BillingStage stage, [String message = '']) {
    state.value = BillingState(stage, message);
  }

  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static Future<bool?>? _refreshFuture;

  // Product IDs defined in Google Play Console
  static const String removeAdsId = 'snapsweep_remove_ads';
  static const Set<String> _productIds = {removeAdsId};

  static final ValueNotifier<bool> isPremiumNotifier = ValueNotifier<bool>(
    false,
  );
  static bool get isPremium => isPremiumNotifier.value;

  static List<ProductDetails> products = [];
  static bool isAvailable = false;

  /// Idempotent initialization keeps a single purchase listener alive.
  static Future<void> initialize() {
    if (_initializing != null) return _initializing!;
    if (_initialized) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  static Future<void> _initialize() async {
    _status(BillingStage.loading);
    try {
      final prefs = await SharedPreferences.getInstance();
      isPremiumNotifier.value = prefs.getBool('is_premium_user') ?? false;
      isAvailable = await _iap.isAvailable().timeout(
        const Duration(seconds: 10),
      );
      if (!isAvailable) {
        _status(
          BillingStage.unavailable,
          'Google Play billing is unavailable. Install SnapSweep from Google Play and try again.',
        );
        return;
      }
      await _subscription?.cancel();
      _subscription = _iap.purchaseStream.listen(
        (purchases) {
          _updates = _updates
              .then((_) => _onPurchaseUpdated(purchases))
              .catchError((Object error) {
                _purchasing = false;
                _status(
                  BillingStage.error,
                  'Could not confirm your purchase. Try Restore purchase.',
                );
              });
        },
        onError: (Object error) {
          _purchasing = false;
          _status(
            BillingStage.error,
            'Google Play could not complete the purchase. Please try again.',
          );
        },
      );
      _initialized = true;
      await refreshEntitlement();
      await loadProducts();
    } catch (error) {
      _status(
        BillingStage.unavailable,
        'Could not connect to Google Play. Check your connection and retry.',
      );
    }
  }

  static Future<void> loadProducts() async {
    if (_purchasing) return;
    _status(BillingStage.loading);
    try {
      final response = await _iap
          .queryProductDetails(_productIds)
          .timeout(const Duration(seconds: 10));
      products = response.productDetails;
      if (response.error != null || removeAdsProduct == null) {
        _status(
          BillingStage.unavailable,
          'The purchase is currently unavailable. Check your connection and try again.',
        );
      } else {
        _status(BillingStage.ready);
      }
    } catch (error) {
      _status(
        BillingStage.error,
        'Could not load the Google Play price. Please retry.',
      );
    }
  }

  static Future<void> retry() async {
    if (_purchasing || state.value.busy) return;
    if (!_initialized) {
      await initialize();
    } else {
      await loadProducts();
    }
  }

  /// Starts checkout. Premium is granted only after Play reports ownership.
  static Future<bool> buyRemoveAds() async {
    if (_purchasing || isPremium || state.value.busy) return false;
    _purchasing = true;
    _status(BillingStage.opening, 'Opening secure Google Play checkout...');
    try {
      final product = removeAdsProduct;
      if (!isAvailable || product == null) {
        _purchasing = false;
        _status(
          BillingStage.unavailable,
          'Load the Google Play price before purchasing.',
        );
        return false;
      }
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _purchasing = false;
        _status(
          BillingStage.error,
          'Checkout could not be opened. Please try again.',
        );
      }
      return started;
    } catch (error) {
      _purchasing = false;
      _status(
        BillingStage.error,
        'Purchase could not be started. Please try again.',
      );
      return false;
    }
  }

  static Future<void> restorePurchases() async {
    if (state.value.stage == BillingStage.restoring ||
        state.value.stage == BillingStage.opening) {
      return;
    }
    if (!_initialized) await initialize();
    if (!isAvailable) return;
    _status(BillingStage.restoring, 'Checking purchases with Google Play...');
    try {
      await _iap.restorePurchases().timeout(const Duration(seconds: 15));
      final owned = await refreshEntitlement();
      if (_purchasing && owned != true) {
        _status(
          BillingStage.pending,
          'Payment is pending. Google Play will confirm when it is complete.',
        );
      } else if (owned == true) {
        _purchasing = false;
        _status(
          BillingStage.success,
          'Your ad-free purchase has been restored.',
        );
      } else if (owned == false) {
        _status(
          BillingStage.ready,
          'No Remove Ads purchase found. Use the Google Play account you purchased with.',
        );
      } else {
        _status(
          BillingStage.error,
          'Could not check ownership. Please try restoring again.',
        );
      }
    } catch (error) {
      _status(
        BillingStage.error,
        'Restoration could not finish. Check your connection and retry.',
      );
    }
  }

  static Future<void> _onPurchaseUpdated(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (purchase.productID != removeAdsId) continue;
      if (purchase.status == PurchaseStatus.pending) {
        _purchasing = true;
        _status(
          BillingStage.pending,
          'Payment is pending. Google Play will confirm when it is complete.',
        );
      } else if (purchase.status == PurchaseStatus.canceled) {
        _purchasing = false;
        _status(
          BillingStage.cancelled,
          'Purchase cancelled. You have not unlocked Remove Ads.',
        );
      } else if (purchase.status == PurchaseStatus.error) {
        _purchasing = false;
        _status(
          BillingStage.error,
          'Google Play could not complete the purchase. Please try again.',
        );
      } else if (isPurchaseCandidate(purchase)) {
        var owned = await refreshEntitlement();
        if (owned == false) {
          await Future<void>.delayed(const Duration(seconds: 1));
          owned = await refreshEntitlement();
        }
        _purchasing = false;
        if (owned == true) {
          _status(
            BillingStage.success,
            'Ads are now removed. Thank you for supporting SnapSweep.',
          );
        } else {
          _status(
            BillingStage.error,
            'Payment confirmation is not available yet. Try Restore purchase before buying again.',
          );
        }
      }
    }
  }

  @visibleForTesting
  static bool isPurchaseCandidate(PurchaseDetails purchase) {
    return purchase.productID == removeAdsId &&
        (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) &&
        purchase.verificationData.source == 'google_play' &&
        purchase.verificationData.serverVerificationData.isNotEmpty;
  }

  /// Returns null if Google Play could not be queried. The stored entitlement
  /// is retained in that case so a paid user can still use the app offline.
  static Future<bool?> refreshEntitlement() {
    if (defaultTargetPlatform != TargetPlatform.android || !isAvailable) {
      return Future.value(null);
    }
    return _refreshFuture ??= _queryOwnedPurchase();
  }

  static Future<void> reconcileOnResume() async {
    final owned = await refreshEntitlement();
    if (state.value.stage == BillingStage.opening) {
      _purchasing = false;
      _status(
        owned == true ? BillingStage.success : BillingStage.cancelled,
        owned == true
            ? 'Your ad-free purchase is active.'
            : 'Checkout closed. You can try again or restore a previous purchase.',
      );
    } else if (owned == true && state.value.stage == BillingStage.pending) {
      _purchasing = false;
      _status(BillingStage.success, 'Your ad-free purchase is active.');
    }
  }

  static Future<bool?> _queryOwnedPurchase() async {
    try {
      final addition = _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases().timeout(
        const Duration(seconds: 10),
      );
      if (response.error != null) {
        debugPrint(
          '[BillingService] Ownership query error: ${response.error!.message}',
        );
        return null;
      }
      final owned = response.pastPurchases.any(isPurchaseCandidate);
      if (!owned &&
          response.pastPurchases.any(
            (purchase) =>
                purchase.productID == removeAdsId &&
                purchase.status == PurchaseStatus.pending,
          )) {
        _purchasing = true;
        _status(
          BillingStage.pending,
          'Payment is pending. Google Play will confirm when it is complete.',
        );
      }
      await _setPremium(owned);
      if (owned) {
        for (final purchase in response.pastPurchases.where(
          isPurchaseCandidate,
        )) {
          if (purchase.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchase);
            } catch (error) {
              debugPrint(
                '[BillingService] Acknowledgement will be retried: $error',
              );
            }
          }
        }
      }
      return owned;
    } catch (e) {
      debugPrint('[BillingService] Ownership query failed: $e');
      return null;
    } finally {
      _refreshFuture = null;
    }
  }

  static Future<void> _setPremium(bool value) async {
    isPremiumNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium_user', value);
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    _purchasing = false;
  }
}
