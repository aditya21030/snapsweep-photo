import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../providers/scan_provider.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  static const _platform = MethodChannel('com.yousful.snapsweep/gallery');

  Future<void> _openSystemTrash(BuildContext context) async {
    HapticFeedback.selectionClick();
    try {
      final success = await _platform.invokeMethod<bool>('openGalleryTrash');
      if (success != true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please open your phone Gallery or Google Photos to view Trash.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Open your device Gallery or Google Photos app > Trash to view.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : AppColors.ink;
    final mutedColor = isDark ? const Color(0xFFA49EBA) : const Color(0xFF5F567A);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryTextColor, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Trash & Recovery',
          style: AppTypography.heading20(color: primaryTextColor),
        ),
        centerTitle: true,
      ),
      body: Consumer<ScanProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              // Hero Info Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.ink2 : AppColors.ink,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.violet.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete_sweep_rounded,
                            color: AppColors.ink,
                            size: 24,
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '30-Day Recovery Shield',
                                style: AppTypography.heading20(color: Colors.white),
                              ),
                              const Gap(2),
                              Text(
                                'Your photos are safe',
                                style: AppTypography.meta13(color: AppColors.lilac),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Gap(16),
                    Text(
                      'SnapSweep never permanently removes your photos without permission. All items cleaned or swiped away are safely sent to your Android system Trash (Recently Deleted).',
                      style: AppTypography.body15(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                    const Gap(8),
                    Text(
                      'They remain safely restorable for 30 days in your phone Gallery or Google Photos.',
                      style: AppTypography.body15(color: AppColors.gold, fontWeight: FontWeight.w600),
                    ),
                    const Gap(20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.ink,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => _openSystemTrash(context),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(
                          'Open Phone Gallery Trash',
                          style: AppTypography.button15(color: AppColors.ink),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Gap(24),

              // Session Cleaning Statistics Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.ink2 : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.lilac2.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          color: AppColors.violet,
                          size: 20,
                        ),
                        const Gap(8),
                        Text(
                          'Cleaned This Session',
                          style: AppTypography.subheading17(color: primaryTextColor),
                        ),
                      ],
                    ),
                    const Gap(14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : AppColors.lilac.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${provider.sessionTrashedCount}',
                                  style: AppTypography.title30(color: primaryTextColor),
                                ),
                                const Gap(2),
                                Text(
                                  'Items moved to Trash',
                                  style: AppTypography.caption11(color: mutedColor, letterSpacing: 0),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : AppColors.lilac.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.sessionTrashedBytes > 0
                                      ? provider.formattedSessionTrashedBytes
                                      : '0 B',
                                  style: AppTypography.title30(color: primaryTextColor),
                                ),
                                const Gap(2),
                                Text(
                                  'Space freed up',
                                  style: AppTypography.caption11(color: mutedColor, letterSpacing: 0),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Gap(24),

              // How to Restore Step-by-Step Guide
              Text(
                'How to Restore Photos',
                style: AppTypography.subheading17(color: primaryTextColor),
              ),
              const Gap(12),

              _buildGuideStep(
                context: context,
                stepNumber: '1',
                title: 'Open your phone gallery',
                desc: 'Open Google Photos, Samsung Gallery, or your device default photo album.',
                isDark: isDark,
                primaryTextColor: primaryTextColor,
                mutedColor: mutedColor,
              ),
              const Gap(10),
              _buildGuideStep(
                context: context,
                stepNumber: '2',
                title: 'Navigate to Trash or Bin',
                desc: 'Look under Library or Albums and tap "Trash" or "Recently Deleted".',
                isDark: isDark,
                primaryTextColor: primaryTextColor,
                mutedColor: mutedColor,
              ),
              const Gap(10),
              _buildGuideStep(
                context: context,
                stepNumber: '3',
                title: 'Tap Restore',
                desc: 'Select any photos or videos you want to keep and tap "Restore". They instantly reappear in your camera roll.',
                isDark: isDark,
                primaryTextColor: primaryTextColor,
                mutedColor: mutedColor,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGuideStep({
    required BuildContext context,
    required String stepNumber,
    required String title,
    required String desc,
    required bool isDark,
    required Color primaryTextColor,
    required Color mutedColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.ink2 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.lilac2.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.violet,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body15(
                    color: primaryTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Gap(3),
                Text(
                  desc,
                  style: AppTypography.meta13(color: mutedColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
