import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gap/gap.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';

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
        final statuses = await [Permission.photos, Permission.videos].request();
        final photosOk = statuses[Permission.photos]?.isGranted == true ||
            statuses[Permission.photos]?.isLimited == true;
        final videosOk = statuses[Permission.videos]?.isGranted == true ||
            statuses[Permission.videos]?.isLimited == true;
        granted = photosOk || videosOk;
      } else {
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
            backgroundColor: AppColors.ink,
            content: Text(
              'Permission required to scan and clean gallery.',
              style: AppTypography.body15(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'Settings',
              textColor: AppColors.gold,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.ink : AppColors.lavender;
    final cardBg = isDark ? AppColors.ink2 : Colors.white;
    final primaryTextColor = isDark ? Colors.white : AppColors.ink;
    final secondaryTextColor =
        isDark ? const Color(0xFFA49EBA) : const Color(0xFF5F567A);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Gap(16),

              // Top Graphic Illustration Container (Page 4 / 34)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0C0220) : AppColors.ink,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    // Row 1 of photo cards
                    Row(
                      children: [
                        _buildPhotoCard(
                          bg: AppColors.lilac,
                          mountainColor: AppColors.violet,
                          sunColor: AppColors.gold,
                        ),
                        const Gap(10),
                        _buildPhotoCard(
                          bg: AppColors.gold,
                          mountainColor: AppColors.ink,
                          sunColor: Colors.white,
                          isHighlighted: true,
                        ),
                        const Gap(10),
                        _buildPhotoCard(
                          bg: AppColors.violet,
                          mountainColor: AppColors.violetDeep,
                          sunColor: AppColors.gold,
                        ),
                      ],
                    ),
                    const Gap(10),
                    // Row 2 of photo cards
                    Row(
                      children: [
                        _buildPhotoCard(
                          bg: AppColors.violet,
                          mountainColor: const Color(0xFF4311B0),
                          sunColor: Colors.white,
                        ),
                        const Gap(10),
                        _buildPhotoCard(
                          bg: AppColors.lilac,
                          mountainColor: AppColors.violet,
                          sunColor: Colors.white,
                        ),
                        const Gap(10),
                        _buildPhotoCard(
                          bg: AppColors.lilac,
                          mountainColor: AppColors.ink,
                          sunColor: AppColors.gold,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Gap(28),

              // Title
              Text(
                "Let SnapSweep look at\nyour gallery",
                textAlign: TextAlign.center,
                style: AppTypography.title30(
                  color: primaryTextColor,
                ).copyWith(fontSize: 26, height: 1.2),
              ),

              const Gap(12),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  "Photo access is used only to scan the gallery area you choose and find space you can safely review.",
                  textAlign: TextAlign.center,
                  style: AppTypography.body15(
                    color: secondaryTextColor,
                    height: 1.4,
                  ),
                ),
              ),

              const Gap(28),

              // 3 Value Benefit Cards
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.lilac2.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    _buildBenefitRow(
                      icon: Icons.phone_android_rounded,
                      title: "Scans on your phone",
                      subtitle: "Nothing is uploaded",
                      primaryText: primaryTextColor,
                      secondaryText: secondaryTextColor,
                      iconBg: isDark
                          ? const Color(0xFF281357)
                          : AppColors.lilac,
                      iconColor: AppColors.violet,
                    ),
                    Divider(
                      height: 1,
                      indent: 72,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : AppColors.lilac.withValues(alpha: 0.7),
                    ),
                    _buildBenefitRow(
                      icon: Icons.delete_outline_rounded,
                      title: "Direct Storage Recovery",
                      subtitle: "Frees device space instantly",
                      primaryText: primaryTextColor,
                      secondaryText: secondaryTextColor,
                      iconBg: isDark
                          ? const Color(0xFF281357)
                          : AppColors.lilac,
                      iconColor: AppColors.violet,
                    ),
                    Divider(
                      height: 1,
                      indent: 72,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : AppColors.lilac.withValues(alpha: 0.7),
                    ),
                    _buildBenefitRow(
                      icon: Icons.lock_outline_rounded,
                      title: "No account needed",
                      subtitle: "No sign-up, no tracking",
                      primaryText: primaryTextColor,
                      secondaryText: secondaryTextColor,
                      iconBg: isDark
                          ? const Color(0xFF281357)
                          : AppColors.lilac,
                      iconColor: AppColors.violet,
                    ),
                  ],
                ),
              ),

              const Gap(32),

              // Allow Access Primary Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isRequesting ? null : _requestPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isRequesting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          "Allow access",
                          style: AppTypography.button15(color: Colors.white)
                              .copyWith(fontSize: 16),
                        ),
                ),
              ),

              const Gap(12),

              // Open Settings Text Button
              TextButton(
                onPressed: () => openAppSettings(),
                child: Text(
                  "Open settings",
                  style: AppTypography.button15(
                    color: AppColors.violet,
                  ),
                ),
              ),

              const Gap(16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color primaryText,
    required Color secondaryText,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body15(
                    color: primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(2),
                Text(
                  subtitle,
                  style: AppTypography.meta13(
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard({
    required Color bg,
    required Color mountainColor,
    required Color sunColor,
    bool isHighlighted = false,
  }) {
    return Expanded(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: isHighlighted
                  ? Border.all(color: AppColors.gold, width: 2.5)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: sunColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: mountainColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isHighlighted)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 12,
                  color: AppColors.ink,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
