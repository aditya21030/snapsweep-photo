import 'package:flutter_test/flutter_test.dart';
import 'package:snapsweep/core/services/ad_service.dart';

void main() {
  test('completion ad policy respects premium, ready, and allowed flags', () {
    final policy = CompletionAdPolicy();
    expect(policy.consume(premium: true, ready: true, allowed: true), false);
    expect(policy.consume(premium: false, ready: false, allowed: true), false);
    expect(policy.consume(premium: false, ready: true, allowed: false), false);
    expect(policy.consume(premium: false, ready: true, allowed: true), true);
    // Immediate subsequent deletion is throttled by cooldown
    expect(policy.consume(premium: false, ready: true, allowed: true), false);
  });

  test('cooldown allows subsequent clean ads after cooldown window', () {
    var now = DateTime.utc(2026, 11, 6, 12);
    final policy = CompletionAdPolicy(clock: () => now);
    expect(policy.consume(premium: false, ready: true, allowed: true), true);
    // After 6 seconds (greater than 5s cooldown), next ad is permitted
    now = now.add(const Duration(seconds: 6));
    expect(policy.consume(premium: false, ready: true, allowed: true), true);
  });

  test('cooldown restored after restart prevents another immediate ad', () {
    var now = DateTime.utc(2026, 11, 6, 12);
    final policy = CompletionAdPolicy(clock: () => now);
    policy.restoreCooldown(now.subtract(const Duration(seconds: 2)));
    expect(policy.consume(premium: false, ready: true, allowed: true), false);
    now = now.add(const Duration(seconds: 4));
    expect(policy.consume(premium: false, ready: true, allowed: true), true);
  });
}
