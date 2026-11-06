import 'package:flutter_test/flutter_test.dart';
import 'package:snapsweep/core/services/ad_service.dart';

void main() {
  test('one shared completion ad per session across all features', () {
    final policy = CompletionAdPolicy();
    expect(policy.consume(premium: true, ready: true, allowed: true), false);
    expect(policy.consume(premium: false, ready: false, allowed: true), false);
    expect(policy.consume(premium: false, ready: true, allowed: false), false);
    expect(policy.consume(premium: false, ready: true, allowed: true), true);
    expect(policy.consume(premium: false, ready: true, allowed: true), false);
  });
  test('cooldown restored after restart prevents another immediate ad', () {
    var now = DateTime.utc(2026, 11, 6, 12);
    final policy = CompletionAdPolicy(clock: () => now);
    policy.restoreCooldown(now.subtract(const Duration(minutes: 2)));
    expect(policy.consume(premium: false, ready: true, allowed: true), false);
    now = now.add(const Duration(minutes: 1));
    expect(policy.consume(premium: false, ready: true, allowed: true), true);
  });
}
