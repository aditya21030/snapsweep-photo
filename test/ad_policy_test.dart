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
    // After 50 seconds (greater than 45s cooldown), next ad is permitted
    now = now.add(const Duration(seconds: 50));
    expect(policy.consume(premium: false, ready: true, allowed: true), true);
  });

  test('cooldown restored after restart prevents another immediate ad', () {
    var now = DateTime.utc(2026, 11, 6, 12);
    final policy = CompletionAdPolicy(clock: () => now);
    policy.restoreCooldown(now.subtract(const Duration(seconds: 20)));
    expect(policy.consume(premium: false, ready: true, allowed: true), false);
    now = now.add(const Duration(seconds: 30));
    expect(policy.consume(premium: false, ready: true, allowed: true), true);
  });
}
