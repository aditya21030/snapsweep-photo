import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/services/billing_service.dart';

Future<bool> checkInternetAccess() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
  try {
    final request = await client
        .getUrl(Uri.parse('https://www.gstatic.com/generate_204'))
        .timeout(const Duration(seconds: 4));
    final response = await request.close().timeout(const Duration(seconds: 4));
    final reachable = response.statusCode == 204;
    await response.drain<void>().timeout(const Duration(seconds: 4));
    return reachable;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

class OnlineGate extends StatefulWidget {
  const OnlineGate({
    super.key,
    required this.child,
    this.connectionCheck = checkInternetAccess,
  });
  final Widget child;
  final Future<bool> Function() connectionCheck;
  @override
  State<OnlineGate> createState() => _OnlineGateState();
}

class _OnlineGateState extends State<OnlineGate> with WidgetsBindingObserver {
  Timer? _timer;
  bool _online = false;
  bool _opened = false;
  bool _checking = false;
  bool _initialCheckCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BillingService.isPremiumNotifier.addListener(_premiumChanged);
    _check();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _check());
  }

  void _premiumChanged() {
    if (mounted) setState(() {});
    _check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking || BillingService.isPremium) return;
    setState(() => _checking = true);
    bool reachable = false;
    try {
      reachable = await widget.connectionCheck().timeout(
        const Duration(seconds: 12),
      );
    } catch (_) {
      reachable = false;
    }
    if (!mounted) return;
    setState(() {
      _online = reachable;
      _opened = _opened || reachable;
      _checking = false;
      _initialCheckCompleted = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    BillingService.isPremiumNotifier.removeListener(_premiumChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed = BillingService.isPremium ||
        _online ||
        (!_initialCheckCompleted && _checking);
    return Stack(
      children: [
        if (_opened || allowed)
          Offstage(offstage: !allowed, child: widget.child),
        if (!allowed)
          Positioned.fill(
            child: Scaffold(
              body: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 56),
                        const SizedBox(height: 20),
                        Text(
                          'Internet connection required',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'The free version requires an internet connection. Connect to Wi-Fi or mobile data, then try again.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        if (_checking)
                          const CircularProgressIndicator()
                        else
                          FilledButton(
                            onPressed: _check,
                            child: const Text('Try again'),
                          ),
                        TextButton(
                          onPressed: _checking
                              ? null
                              : BillingService.restorePurchases,
                          child: const Text('Restore ad-free purchase'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
