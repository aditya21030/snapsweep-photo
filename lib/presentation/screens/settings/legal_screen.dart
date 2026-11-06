import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.ink : AppColors.lavender;
    final cardBg = isDark ? AppColors.ink2 : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.ink;
    final mutedColor = isDark
        ? AppColors.lavender.withValues(alpha: 0.7)
        : AppColors.ink.withValues(alpha: 0.6);

    final sanitizedContent = content
        .replaceAll('\u2022', '-')
        .replaceAll(RegExp(r'^#{1,2}\s*', multiLine: true), '')
        .replaceAll('**', '');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: AppTypography.heading20(color: textColor)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.violet.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield_rounded,
                            color: AppColors.violet,
                            size: 20,
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Text(
                            'On-device media analysis',
                            style: AppTypography.subheading17(color: textColor),
                          ),
                        ),
                      ],
                    ),
                    const Gap(14),
                    Text(
                      'Gallery analysis happens on your device. Ads and Google Play Billing use online services; their data practices are described below.',
                      style: AppTypography.body15(color: mutedColor),
                    ),
                  ],
                ),
              ),
              const Gap(16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  sanitizedContent,
                  style: AppTypography.body15(color: textColor, height: 1.6),
                ),
              ),
              const Gap(40),
            ],
          ),
        ),
      ),
    );
  }
}
