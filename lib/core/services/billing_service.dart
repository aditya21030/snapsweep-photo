import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BillingService {
  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Product IDs defined in Google Play Console
  static const String removeAdsId = 'snapsweep_remove_ads';
  static const Set<String> _productIds = {removeAdsId};

  static final ValueNotifier<bool> isPremiumNotifier = ValueNotifier<bool>(false);
  static bool get isPremium => isPremiumNotifier.value;

  static List<ProductDetails> products = [];
  static bool isAvailable = false;

  /// Initialize Google Play Billing and restore saved state
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool savedPremium = prefs.getBool('is_premium_user') ?? false;
      isPremiumNotifier.value = savedPremium;

      isAvailable = await _iap.isAvailable();
      if (!isAvailable) {
        debugPrint('[BillingService] Store not available');
        return;
      }

      // Listen for purchase updates
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdated,
        onDone: () => _subscription?.cancel(),
        onError: (error) => debugPrint('[BillingService] Stream error: $error'),
      );

      // Load products
      await loadProducts();
    } catch (e) {
      debugPrint('[BillingService] Init error: $e');
    }
  }

  /// Query product details from Google Play
  static Future<void> loadProducts() async {
    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(_productIds);
      if (response.error != null) {
        debugPrint('[BillingService] Query error: ${response.error!.message}');
        return;
      }
      products = response.productDetails;
      debugPrint('[BillingService] Loaded ${products.length} products');
    } catch (e) {
      debugPrint('[BillingService] Load products error: $e');
    }
  }

  /// Purchase remove ads
  static Future<bool> buyRemoveAds() async {
    try {
      if (!isAvailable) {
        await initialize();
      }

      ProductDetails? product;
      for (final p in products) {
        if (p.id == removeAdsId) {
          product = p;
          break;
        }
      }

      // If product details not cached, query again
      if (product == null) {
        await loadProducts();
        for (final p in products) {
          if (p.id == removeAdsId) {
            product = p;
            break;
          }
        }
      }

      if (product == null) {
        debugPrint('[BillingService] Product $removeAdsId not found in store');
        return false;
      }

      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('[BillingService] Purchase error: $e');
      return false;
    }
  }

  /// Restore purchases
  static Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('[BillingService] Restore error: $e');
    }
  }

  static Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('[BillingService] Purchase pending');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('[BillingService] Purchase error: ${purchaseDetails.error?.message}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          final bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            await _setPremium(true);
            debugPrint('[BillingService] Premium activated');
          }
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  static Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // Valid for standard non-consumable in Google Play Store
    return purchaseDetails.productID == removeAdsId;
  }

  static Future<void> _setPremium(bool value) async {
    isPremiumNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium_user', value);
  }

  static void dispose() {
    _subscription?.cancel();
  }
}
