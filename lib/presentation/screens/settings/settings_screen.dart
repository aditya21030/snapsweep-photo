import '../../../core/services/ad_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/legal_content.dart';
import '../../../core/services/billing_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../providers/theme_provider.dart';
import 'legal_screen.dart';
import 'remove_ads_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _versionLabel = 'SnapSweep';
  @override
  void initState() {
    super.initState();
    const MethodChannel('com.yousful.snapsweep/gallery')
        .invokeMethod<String>('getAppVersion')
        .then((label) {
          if (mounted && label != null) setState(() => _versionLabel = label);
        })
        .catchError((Object error) {
          debugPrint('[App version] $error');
        });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.ink : AppColors.lavender;
    final cardBg = isDark ? AppColors.ink2 : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.ink;
    final mutedColor = isDark
        ? AppColors.lavender.withValues(alpha: 0.7)
        : AppColors.ink.withValues(alpha: 0.6);
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Settings',
          style: AppTypography.heading20(color: textColor),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          40 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: BillingService.isPremiumNotifier,
            builder: (context, active, _) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Material(
                color: AppColors.ink2,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RemoveAdsScreen(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      children: [
                        Icon(
                          active ? Icons.verified_rounded : Icons.block_rounded,
                          color: AppColors.gold,
                          size: 30,
                        ),
                        const Gap(16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                active ? 'Ads removed' : 'Remove Ads',
                                style: AppTypography.heading20(
                                  color: Colors.white,
                                ),
                              ),
                              const Gap(6),
                              Text(
                                active
                                    ? 'Your one-time purchase is active'
                                    : 'Pay once. Enjoy an ad-free SnapSweep.',
                                style: const TextStyle(
                                  color: AppColors.lilac,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Section: Appearance
          _buildSectionHeader('Appearance', mutedColor),
          _buildThemeTileWithSegments(
            context,
            themeProvider: themeProvider,
            cardBg: cardBg,
            textColor: textColor,
            mutedColor: mutedColor,
            isDark: isDark,
          ),

          const Gap(20),

          // Section: Purchases
          _buildSectionHeader('Purchases', mutedColor),
          _buildSettingsTile(
            context,
            icon: Icons.restore_rounded,
            title: 'Restore Purchases',
            subtitle: 'Restore previous Google Play purchases',
            cardBg: cardBg,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RemoveAdsScreen(),
                ),
              );
              BillingService.restorePurchases();
            },
          ),

          const Gap(20),

          // Section: Support
          _buildSectionHeader('Support', mutedColor),
          _buildSettingsTile(
            context,
            icon: Icons.star_outline_rounded,
            title: 'Rate SnapSweep',
            subtitle: 'Love SnapSweep? Leave a review on Google Play',
            cardBg: cardBg,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () async {
              final Uri playStoreUri = Uri.parse(
                'https://play.google.com/store/apps/details?id=com.yousful.snapsweep',
              );
              try {
                if (await canLaunchUrl(playStoreUri)) {
                  await launchUrl(
                    playStoreUri,
                    mode: LaunchMode.externalApplication,
                  );
                }
              } catch (_) {}
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.share_outlined,
            title: 'Share with Friends',
            subtitle: 'Tell your friends about SnapSweep',
            cardBg: cardBg,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () async {
              try {
                await Share.share(
                  'Check out SnapSweep! A smart, flat gallery cleaner for Android. Download now: https://play.google.com/store/apps/details?id=com.yousful.snapsweep',
                );
              } catch (e) {
                debugPrint('Share Error: $e');
              }
            },
          ),

          const Gap(20),

          // Section: About & Legal
          _buildSectionHeader('About', mutedColor),
          ValueListenableBuilder<bool>(
            valueListenable: AdService.privacyOptionsRequired,
            builder: (context, required, _) => !required
                ? const SizedBox.shrink()
                : _buildSettingsTile(
                    context,
                    icon: Icons.privacy_tip_outlined,
                    title: 'Advertising privacy choices',
                    subtitle: 'Review or change your advertising consent',
                    cardBg: cardBg,
                    textColor: textColor,
                    mutedColor: mutedColor,
                    onTap: () async {
                      try {
                        await AdService.showPrivacyOptions();
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Privacy choices are currently unavailable. Please try again.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.shield_outlined,
            title: 'Privacy Policy',
            subtitle: 'On-device gallery analysis and service disclosures',
            cardBg: cardBg,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LegalScreen(
                    title: 'Privacy Policy',
                    content: LegalContent.privacyPolicy,
                  ),
                ),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.description_outlined,
            title: 'Terms and Conditions',
            subtitle: 'Cleanup, advertising, purchases and your rights',
            cardBg: cardBg,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LegalScreen(
                    title: 'Terms and Conditions',
                    content: LegalContent.termsOfService,
                  ),
                ),
              );
            },
          ),

          const Gap(28),

          // Version Footer
          Center(
            child: Column(
              children: [
                Text(
                  'SnapSweep',
                  style: AppTypography.heading20(color: textColor),
                ),
                const Gap(4),
                Text(
                  _versionLabel,
                  style: AppTypography.caption11(
                    color: mutedColor,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const Gap(40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.caption11(color: mutedColor, letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required Color cardBg,
    required Color textColor,
    required Color mutedColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.violet, size: 20),
                ),
                const Gap(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.subheading17(color: textColor),
                      ),
                      if (subtitle != null) ...[
                        const Gap(2),
                        Text(
                          subtitle,
                          style: AppTypography.caption11(
                            color: mutedColor,
                            letterSpacing: 0,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: mutedColor, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppColors.ink2 : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.ink;
    final mutedColor = isDark
        ? AppColors.lavender.withValues(alpha: 0.7)
        : AppColors.ink.withValues(alpha: 0.6);
    final themeProvider = context.read<ThemeProvider>();
    ThemeMode tempSelected = themeProvider.themeMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: mutedColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Gap(18),
                    Text(
                      'Choose theme',
                      style: AppTypography.heading20(color: textColor),
                    ),
                    const Gap(18),
                    _buildThemeOption(
                      context,
                      title: 'System default',
                      mode: ThemeMode.system,
                      current: tempSelected,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      onTap: () =>
                          setSheetState(() => tempSelected = ThemeMode.system),
                    ),
                    const Gap(10),
                    _buildThemeOption(
                      context,
                      title: 'Light mode',
                      mode: ThemeMode.light,
                      current: tempSelected,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      onTap: () =>
                          setSheetState(() => tempSelected = ThemeMode.light),
                    ),
                    const Gap(10),
                    _buildThemeOption(
                      context,
                      title: 'Dark mode',
                      mode: ThemeMode.dark,
                      current: tempSelected,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      onTap: () =>
                          setSheetState(() => tempSelected = ThemeMode.dark),
                    ),
                    const Gap(20),
                    // Violet Apply Button (Page 27)
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.violet,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        themeProvider.setThemeMode(tempSelected);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Apply',
                        style: AppTypography.button15(
                          color: Colors.white,
                        ).copyWith(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeTileWithSegments(
    BuildContext context, {
    required ThemeProvider themeProvider,
    required Color cardBg,
    required Color textColor,
    required Color mutedColor,
    required bool isDark,
  }) {
    final currentMode = themeProvider.themeMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.palette_outlined,
                  color: AppColors.violet,
                  size: 20,
                ),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: AppTypography.subheading17(color: textColor),
                    ),
                    const Gap(2),
                    Text(
                      'Choose your interface appearance',
                      style: AppTypography.caption11(
                        color: mutedColor,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.tune_rounded, color: mutedColor, size: 20),
                tooltip: 'More theme options',
                onPressed: () => _showThemeDialog(context),
              ),
            ],
          ),
          const Gap(14),
          // 3-Segment Switcher Pill: Auto | Light | Dark (Page 26)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.ink : AppColors.lavender,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildSegmentPill(
                  label: 'Auto',
                  isSelected: currentMode == ThemeMode.system,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    themeProvider.setThemeMode(ThemeMode.system);
                  },
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
                _buildSegmentPill(
                  label: 'Light',
                  isSelected: currentMode == ThemeMode.light,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    themeProvider.setThemeMode(ThemeMode.light);
                  },
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
                _buildSegmentPill(
                  label: 'Dark',
                  isSelected: currentMode == ThemeMode.dark,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    themeProvider.setThemeMode(ThemeMode.dark);
                  },
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color textColor,
    required Color mutedColor,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.violet : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.meta13(
                color: isSelected ? Colors.white : mutedColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required ThemeMode mode,
    required ThemeMode current,
    required Color textColor,
    required Color mutedColor,
    required VoidCallback onTap,
  }) {
    final isSelected = mode == current;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isSelected
          ? (isDark ? AppColors.violet.withValues(alpha: 0.2) : AppColors.lilac)
          : (isDark ? AppColors.ink : AppColors.lavender),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.subheading17(
                  color: isSelected ? AppColors.violet : textColor,
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.violet,
                  size: 20,
                )
              else
                Icon(Icons.circle_outlined, color: mutedColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
