import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gap/gap.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../core/constants/app_colors.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _isRequesting = false;

  Future<void> _requestPermission() async {
    if (_isRequesting) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isRequesting = true;
    });

    bool granted = false;

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ (request both photos and videos for gallery & video cleanup)
        final statuses = await [Permission.photos, Permission.videos].request();
        final photosOk = statuses[Permission.photos]?.isGranted == true || statuses[Permission.photos]?.isLimited == true;
        final videosOk = statuses[Permission.videos]?.isGranted == true || statuses[Permission.videos]?.isLimited == true;
        granted = photosOk || videosOk;
      } else {
        // Android < 13
        final status = await Permission.storage.request();
        granted = status.isGranted;
      }
    } else {
      final status = await Permission.photos.request();
      granted = status.isGranted || status.isLimited;
    }

    setState(() {
      _isRequesting = false;
    });

    if (granted) {
      HapticFeedback.mediumImpact();
      if (mounted) context.go('/home');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Permission required to scan and clean gallery.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 12),
              
              // Privacy Trust Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.green, size: 16),
                    Gap(8),
                    Text(
                      "100% On-Device | Photos Never Uploaded",
                      style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              // Hero Center Graphic
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.15),
                          AppColors.secondary.withValues(alpha: 0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      size: 68,
                      color: AppColors.primary,
                    ),
                  ),
                  const Gap(24),
                  Text(
                    "Clean & Optimize Your Photos",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(8),
                  Text(
                    "SnapSweep needs access to your gallery to find duplicate copies, blurry shots, and organize categories.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondary,
                          height: 1.4,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(28),

                  // 3 Feature Cards
                  _buildFeatureRow(
                    icon: Icons.copy_rounded,
                    title: "Find Exact Duplicate Copies",
                    subtitle: "Safely delete redundant identical files.",
                  ),
                  const Gap(16),
                  _buildFeatureRow(
                    icon: Icons.blur_on_rounded,
                    title: "Detect Blurry Shots & Large Videos",
                    subtitle: "Free up storage by reviewing out-of-focus media.",
                  ),
                  const Gap(16),
                  _buildFeatureRow(
                    icon: Icons.grid_view_rounded,
                    title: "Smart Category Organizer",
                    subtitle: "Screenshots, WhatsApp media, and receipts.",
                  ),
                ],
              ),

              // Bottom Action Button
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _requestPermission,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: _isRequesting
                          ? const SizedBox.shrink()
                          : const Icon(Icons.lock_open_rounded, size: 20),
                      label: _isRequesting
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : const Text(
                              "Allow Gallery Access",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const Gap(12),
                  const Text(
                    "All processing is done completely offline on your device.",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const Gap(14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
