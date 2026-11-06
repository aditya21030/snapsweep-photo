import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapsweep/core/services/billing_service.dart';
import 'package:snapsweep/presentation/screens/settings/remove_ads_screen.dart';

class TestStore extends InAppPurchasePlatform {
  final events = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <PurchaseDetails>[];
  int checkoutCount = 0;
  bool productAvailable = true;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => events.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: productAvailable
        ? [
            ProductDetails(
              id: BillingService.removeAdsId,
              title: 'Remove Ads',
              description: 'Ad-free',
              price: '₹149.00',
              rawPrice: 149,
              currencyCode: 'INR',
            ),
          ]
        : [],
    notFoundIDs: productAvailable ? [] : identifiers.toList(),
  );
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    checkoutCount++;
    expect(purchaseParam.productDetails.id, 'snapsweep_remove_ads');
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
    purchase.pendingCompletePurchase = false;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}
}

class TestOwnership extends InAppPurchasePlatformAddition
    implements InAppPurchaseAndroidPlatformAddition {
  List<GooglePlayPurchaseDetails> owned = [];
  bool fail = false;
  @override
  Future<QueryPurchaseDetailsResponse> queryPastPurchases({
    String? applicationUserName,
  }) async {
    if (fail) throw StateError('Offline');
    return QueryPurchaseDetailsResponse(pastPurchases: owned);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GooglePlayPurchaseDetails purchase(PurchaseStatus status) =>
    GooglePlayPurchaseDetails(
      productID: BillingService.removeAdsId,
      verificationData: PurchaseVerificationData(
        localVerificationData: '{}',
        serverVerificationData: 'play-token',
        source: 'google_play',
      ),
      transactionDate: '1',
      status: status,
      billingClientPurchase: const PurchaseWrapper(
        orderId: 'order',
        packageName: 'com.yousful.snapsweep',
        purchaseTime: 1,
        purchaseToken: 'play-token',
        signature: 'signature',
        products: [BillingService.removeAdsId],
        isAutoRenewing: false,
        originalJson: '{}',
        isAcknowledged: false,
        purchaseState: PurchaseStateWrapper.purchased,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestStore store;
  late TestOwnership ownership;
  setUpAll(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = null;
    if (const bool.fromEnvironment('CAPTURE_PAYWALL')) {
      const directory = String.fromEnvironment('REVIEW_FONT_DIR');
      final loader = FontLoader('Roboto');
      for (final weight in ['regular', 'bold', 'black']) {
        loader.addFont(
          Future.value(
            ByteData.sublistView(
              await File('$directory/roboto-$weight.ttf').readAsBytes(),
            ),
          ),
        );
      }
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              await File('$directory/materialicons-regular.otf').readAsBytes(),
            ),
          ),
        );
      await icons.load();
    }
  });
  setUp(() async {
    // Initialize the facade before installing our platform fakes.
    InAppPurchase.instance;
    BillingService.dispose();
    SharedPreferences.setMockInitialValues({});
    store = TestStore();
    ownership = TestOwnership();
    InAppPurchasePlatform.instance = store;
    InAppPurchasePlatformAddition.instance = ownership;
    await BillingService.initialize();
  });
  tearDown(() async {
    BillingService.dispose();
    await store.events.close();
    BillingService.isPremiumNotifier.value = false;
  });

  test(
    'pending and cancelled payments never grant entitlement or acknowledge',
    () async {
      expect(await BillingService.buyRemoveAds(), isTrue);
      expect(await BillingService.buyRemoveAds(), isFalse);
      expect(store.checkoutCount, 1);
      store.events.add([purchase(PurchaseStatus.pending)]);
      await Future<void>.delayed(Duration.zero);
      expect(BillingService.state.value.stage, BillingStage.pending);
      expect(BillingService.isPremium, isFalse);
      expect(store.completed, isEmpty);
      store.events.add([purchase(PurchaseStatus.canceled)]);
      await Future<void>.delayed(Duration.zero);
      expect(BillingService.state.value.stage, BillingStage.cancelled);
      expect(BillingService.isPremium, isFalse);
      expect(store.completed, isEmpty);
    },
  );

  test(
    'confirmed ownership unlocks ads and acknowledges; restore preserves offline cache',
    () async {
      final paid = purchase(PurchaseStatus.purchased);
      ownership.owned = [paid];
      store.events.add([paid]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(BillingService.isPremium, isTrue);
      expect(BillingService.state.value.stage, BillingStage.success);
      expect(store.completed, [paid]);
      ownership.fail = true;
      await BillingService.restorePurchases();
      expect(BillingService.isPremium, isTrue);
      expect(BillingService.state.value.stage, BillingStage.error);
      ownership.fail = false;
      ownership.owned = [];
      await BillingService.refreshEntitlement();
      expect(BillingService.isPremium, isFalse);
    },
  );

  test('unconfirmed callback never unlocks or acknowledges', () async {
    ownership.fail = true;
    store.events.add([purchase(PurchaseStatus.purchased)]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(BillingService.isPremium, isFalse);
    expect(store.completed, isEmpty);
    expect(BillingService.state.value.stage, BillingStage.error);
  });

  testWidgets(
    'purchase page uses store price and fits a small screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const RemoveAdsScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('remove_ads_checkout')),
        250,
      );
      await tester.pumpAndSettle();
      expect(find.text('₹149.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('remove_ads_checkout')));
      await tester.pump();
      expect(store.checkoutCount, 1);
      await tester.runAsync(() async {
        store.events.add([purchase(PurchaseStatus.canceled)]);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'reference Remove Ads layout in ${dark ? 'dark' : 'light'} theme',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
              fontFamily: 'Roboto',
              colorSchemeSeed: const Color(0xFF7028FF),
            ),
            home: RepaintBoundary(key: key, child: const RemoveAdsScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('No ads in the app'), findsOneWidget);
        expect(find.text('One payment'), findsOneWidget);
        expect(find.text('Tied to your Google account'), findsOneWidget);
        expect(find.text('₹149.00'), findsOneWidget);
        if (find
            .byKey(const ValueKey('remove_ads_checkout'))
            .evaluate()
            .isEmpty) {
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('remove_ads_checkout')),
            200,
          );
          await tester.pumpAndSettle();
        }
        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('remove_ads_checkout')),
        );
        expect(
          button.style!.backgroundColor!.resolve({}),
          dark ? const Color(0xFFFFCC00) : const Color(0xFF7028FF),
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_PAYWALL')) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final rendered = await boundary.toImage(pixelRatio: 2);
            final bytes = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = Directory('build/ui-review');
            await directory.create(recursive: true);
            await File(
              '${directory.path}/remove-ads-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
