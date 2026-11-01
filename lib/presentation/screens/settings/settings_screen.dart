import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import '../../../core/constants/legal_content.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/scan_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final String _version = '1.0.3';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    // PackageInfo packageInfo = await PackageInfo.fromPlatform();
    // setState(() {
    //   _version = packageInfo.version;
    // });
    // Commented out package_info_plus usage until dependency is confirmed/added. 
    // Manual for now.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Gap(20),
            Text(
              "Settings",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                
              ),
            ),
            const Gap(30),
            
            // Section: General
            _buildSectionHeader("General"),
            _buildSettingsTile(
              context,
              icon: Icons.dark_mode_outlined,
              title: "Appearance",
              subtitle: "Light, Dark, System",
              iconColor: Colors.deepPurple,
              onTap: () {
                _showThemeDialog(context);
              },
            ),
            _buildSettingsTile(
              context,
              icon: Icons.cleaning_services_rounded,
              title: "Clear Cache & Rescan",
              subtitle: "Re-index gallery and reset scan cache",
              iconColor: Colors.teal,
              onTap: () async {
                HapticFeedback.selectionClick();
                final provider = context.read<ScanProvider>();
                await provider.forceRescan();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scan cache cleared. Rescanning gallery...')),
                  );
                }
              },
            ),

            
            const Gap(20),

            // Section: Premium
            _buildSectionHeader("Premium"),
            _buildSettingsTile(
              context,
              icon: Icons.diamond_outlined,
              title: "Remove Ads",
              subtitle: "Enjoy an ad-free experience",
              iconColor: Colors.purple,
              onTap: () {
                _showComingSoon(context);
              },
            ),
            
            const Gap(20),

            // Section: Support
            _buildSectionHeader("Support"),
            _buildSettingsTile(
              context,
              icon: Icons.star_outline_rounded,
              title: "Rate Us",
              subtitle: "Love the app? Let us know!",
              iconColor: Colors.orange,
              onTap: () {
                 _showComingSoon(context);
              },
            ),


            _buildSettingsTile(
              context,
              icon: Icons.share_outlined,
              title: "Share App",
              subtitle: "Share with friends & family",
              iconColor: Colors.blue,
              onTap: () async {
                 final messenger = ScaffoldMessenger.of(context);
                 debugPrint('Share button clicked');
                 try {
                   await Share.share('Check out Snapsweep! A smart cleaner for your gallery. Download now: https://play.google.com/store/apps/details?id=com.yousful.snapsweep');
                   debugPrint('Share dialog shown');
                 } catch (e) {
                   debugPrint('Share Error: $e');
                   if (mounted) {
                     messenger.showSnackBar(SnackBar(content: Text('Share failed: $e')));
                   }
                 }
              },
            ),
            
            const Gap(20),
            
            // Section: About
            _buildSectionHeader("About"),
            _buildSettingsTile(
              context,
              icon: Icons.privacy_tip_outlined,
              title: "Privacy Policy",
              iconColor: Colors.grey,
              onTap: () {
                context.push('/legal', extra: {
                  'title': 'Privacy Policy',
                  'content': LegalContent.privacyPolicy,
                });
              },
            ),
             _buildSettingsTile(
              context,
              icon: Icons.description_outlined,
              title: "Terms of Service",
              iconColor: Colors.grey,
              onTap: () {
                context.push('/legal', extra: {
                  'title': 'Terms of Service',
                  'content': LegalContent.termsOfService,
                });
              },
            ),

            const Gap(40),
            Center(
              child: Text(
                "Version $_version",
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[500] : Colors.grey[400],
                  fontSize: 12
                ),
              ),
            ),
            Gap(90 + MediaQuery.paddingOf(context).bottom), // Dynamic bottom padding for floating nav
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey[600],
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
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
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
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const Gap(2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
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
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Gap(20),
                  Text(
                    "Choose Theme",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Gap(20),
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
                          title: Text("System Default"),
                          value: ThemeMode.system,
                        ),
                        RadioListTile<ThemeMode>(
                          title: Text("Light Mode"),
                          value: ThemeMode.light,
                        ),
                        RadioListTile<ThemeMode>(
                          title: Text("Dark Mode"),
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

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Coming Soon!"),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
