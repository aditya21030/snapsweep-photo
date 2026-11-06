import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapsweep/core/services/billing_service.dart';
import 'package:snapsweep/presentation/common/online_gate.dart';

void main() {
  testWidgets('offline free users are blocked and retry opens saved child', (
    tester,
  ) async {
    BillingService.isPremiumNotifier.value = false;
    var online = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineGate(
          connectionCheck: () async => online,
          child: const Scaffold(body: Text('Gallery')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Internet connection required'), findsOneWidget);
    expect(find.text('Gallery'), findsNothing);
    online = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Gallery'), findsOneWidget);
    online = false;
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.text('Internet connection required'), findsOneWidget);
    expect(find.text('Gallery'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ad-free purchase bypasses network gate', (tester) async {
    BillingService.isPremiumNotifier.value = true;
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineGate(
          connectionCheck: () async => false,
          child: const Text('Ad-free gallery'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Ad-free gallery'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    BillingService.isPremiumNotifier.value = false;
  });
}
