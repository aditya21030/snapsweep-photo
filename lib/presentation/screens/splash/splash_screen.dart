import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'sweeping_splash_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Animation triggers navigation now
  }

  Future<void> _checkPermissionAndNavigate() async {
    if (!mounted) return;

    bool hasPermission = false;

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final photosStatus = await Permission.photos.status;
        final videosStatus = await Permission.videos.status;
        final photosOk = photosStatus.isGranted || photosStatus.isLimited;
        final videosOk = videosStatus.isGranted || videosStatus.isLimited;
        hasPermission = photosOk || videosOk;
      } else {
        final status = await Permission.storage.status;
        hasPermission = status.isGranted;
      }
    } else {
      final status = await Permission.photos.status;
      hasPermission = status.isGranted || status.isLimited;
    }

    if (mounted) {
      if (hasPermission) {
        context.go('/home');
      } else {
        context.go('/permission');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SweepingSplashScreen(
      onAnimationComplete: _checkPermissionAndNavigate,
    );
  }
}
