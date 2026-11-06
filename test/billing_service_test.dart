import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:snapsweep/core/services/billing_service.dart';

PurchaseDetails _purchase({
  String productId = BillingService.removeAdsId,
  PurchaseStatus status = PurchaseStatus.purchased,
  String source = 'google_play',
  String token = 'purchase-token',
}) {
  return PurchaseDetails(
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: token,
      source: source,
    ),
    transactionDate: '1',
    status: status,
  );
}

void main() {
  test('accepts only completed Play purchase candidates', () {
    expect(BillingService.isPurchaseCandidate(_purchase()), isTrue);
    expect(
      BillingService.isPurchaseCandidate(
        _purchase(status: PurchaseStatus.restored),
      ),
      isTrue,
    );
    expect(
      BillingService.isPurchaseCandidate(
        _purchase(status: PurchaseStatus.pending),
      ),
      isFalse,
    );
    expect(
      BillingService.isPurchaseCandidate(_purchase(productId: 'other')),
      isFalse,
    );
    expect(
      BillingService.isPurchaseCandidate(_purchase(source: 'other_store')),
      isFalse,
    );
    expect(BillingService.isPurchaseCandidate(_purchase(token: '')), isFalse);
  });
}
