import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/services/app_update_service.dart';
import '../screens/update/update_available_screen.dart';

class UpdateGate extends StatefulWidget {
  const UpdateGate({
    super.key,
    required this.child,
    this.controller,
    this.enforce,
    this.onAccessGranted,
  });
  final Widget child;
  final AppUpdateController? controller;
  final bool? enforce;
  final VoidCallback? onAccessGranted;
  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  late final AppUpdateController _controller;
  late final bool _enforce;
  bool _opened = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _enforce = widget.enforce ?? (kReleaseMode && Platform.isAndroid);
    _controller = widget.controller ?? AppUpdateController();
    _controller.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    if (_enforce) {
      _timer = Timer.periodic(const Duration(minutes: 5), (_) {
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed) {
          unawaited(_check());
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_enforce) {
        unawaited(_check());
      } else {
        _grantAccess();
      }
    });
  }

  void _grantAccess() {
    if (_opened) return;
    _opened = true;
    widget.onAccessGranted?.call();
  }

  void _changed() {
    if (!mounted) return;
    if (_controller.allowsAccess) _grantAccess();
    setState(() {});
  }

  Future<void> _check() async {
    await _controller.check();
    if (mounted && _controller.resumeRequested && !_controller.updating) {
      await _controller.update();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_enforce && state == AppLifecycleState.resumed) unawaited(_check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_changed);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed = !_enforce || _controller.allowsAccess;
    return Stack(
      children: [
        // Keep the app usable while checking. Only a confirmed newer version
        // may cover the router with the required-update page.
        if (_opened || allowed)
          Offstage(
            offstage: !allowed,
            child: ExcludeFocus(
              excluding: !allowed,
              child: TickerMode(enabled: allowed, child: widget.child),
            ),
          ),
        if (!allowed)
          Positioned.fill(
            child: UpdateAvailableScreen(controller: _controller),
          ),
      ],
    );
  }
}
