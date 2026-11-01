import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gap/gap.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/theme_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/legal_content.dart';
import '../../../core/services/billing_service.dart';
import 'legal_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Section: Preferences
          _buildSectionHeader('Preferences'),
          _buildSettingsTile(
            context,
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: 'System default, light, dark',
            iconColor: AppColors.primary,
            onTap: () {
              _showThemeDialog(context);
            },
          ),

          const Gap(20),

          // Section: Premium & Billing
          _buildSectionHeader('Premium'),
          ValueListenableBuilder<bool>(
            valueListenable: BillingService.isPremiumNotifier,
            builder: (context, isPremium, child) {
              if (isPremium) {
                return _buildSettingsTile(
                  context,
                  icon: Icons.verified_rounded,
                  title: 'Premium Active',
                  subtitle: 'Ad-free experience unlocked for lifetime',
                  iconColor: Colors.amber,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () {},
                );
              }

              return Column(
                children: [
                  _buildSettingsTile(
                    context,
                    icon: Icons.diamond_outlined,
                    title: 'Remove Ads',
                    subtitle: 'Upgrade to Google Play Ad-Free Pro',
                    iconColor: Colors.purpleAccent,
                    onTap: () {
                      _showPurchaseSheet(context);
                    },
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.restore_rounded,
                    title: 'Restore Purchases',
                    subtitle: 'Restore previous Google Play purchases',
                    iconColor: Colors.teal,
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Checking Google Play for previous purchases...')),
                      );
                      await BillingService.restorePurchases();
                    },
                  ),
                ],
              );
            },
          ),

          const Gap(20),

          // Section: Support
          _buildSectionHeader('Support'),
          _buildSettingsTile(
            context,
            icon: Icons.star_outline_rounded,
            title: 'Rate Us',
            subtitle: 'Love SnapSweep? Leave a review!',
            iconColor: Colors.orange,
            onTap: () async {
              final Uri playStoreUri = Uri.parse(
                'https://play.google.com/store/apps/details?id=com.yousful.snapsweep',
              );
              try {
                if (await canLaunchUrl(playStoreUri)) {
                  await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
                }
              } catch (_) {}
            },
          ),

          _buildSettingsTile(
            context,
            icon: Icons.share_outlined,
            title: 'Share App',
            subtitle: 'Share SnapSweep with friends and family',
            iconColor: Colors.blue,
            onTap: () async {
              try {
                await Share.share(
                  'Check out SnapSweep! A smart, ultra-fast gallery cleaner for Android. Download now: https://play.google.com/store/apps/details?id=com.yousful.snapsweep',
                );
              } catch (e) {
                debugPrint('Share Error: $e');
              }
            },
          ),

          const Gap(20),

          // Section: About
          _buildSectionHeader('About'),
          _buildSettingsTile(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            iconColor: Colors.green,
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
            title: 'Terms of Service',
            iconColor: Colors.indigo,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LegalScreen(
                    title: 'Terms of Service',
                    content: LegalContent.termsOfService,
                  ),
                ),
              );
            },
          ),

          const Gap(30),

          // App Version
          Center(
            child: Column(
              children: [
                Text(
                  'SnapSweep',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Gap(4),
                Text(
                  'Version 1.0.3 (Build 4)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const Gap(2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ?? Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPurchaseSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Gap(20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.diamond_rounded, color: Colors.purpleAccent, size: 36),
                ),
                const Gap(16),
                Text(
                  'Upgrade to SnapSweep Pro',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Gap(6),
                Text(
                  'Permanent Ad-Free Experience via Google Play',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                ),
                const Gap(20),
                _buildBenefitRow(context, Icons.block_rounded, '100% Ad-Free across all screens'),
                const Gap(10),
                _buildBenefitRow(context, Icons.speed_rounded, 'Priority background scanner engine'),
                const Gap(10),
                _buildBenefitRow(context, Icons.cloud_done_rounded, 'Permanent lifetime license linked to Google account'),
                const Gap(24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    final success = await BillingService.buyRemoveAds();
                    if (!success) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Starting Google Play billing...')),
                      );
                    }
                  },
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Unlock with Google Play', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBenefitRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const Gap(12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  void _showThemeDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Gap(12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Gap(20),
                  Text(
                    'Choose Theme',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Gap(16),
                  RadioGroup<ThemeMode>(
                    groupValue: themeProvider.themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        themeProvider.setThemeMode(value);
                        Navigator.pop(context);
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        RadioListTile<ThemeMode>(
                          title: Text('System Default'),
                          value: ThemeMode.system,
                        ),
                        RadioListTile<ThemeMode>(
                          title: Text('Light Mode'),
                          value: ThemeMode.light,
                        ),
                        RadioListTile<ThemeMode>(
                          title: Text('Dark Mode'),
                          value: ThemeMode.dark,
                        ),
                      ],
                    ),
                  ),
                  const Gap(20),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
