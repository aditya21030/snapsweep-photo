import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../providers/scan_provider.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../data/services/media_service.dart';

class CleanerTab extends StatelessWidget {
  const CleanerTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 130 + MediaQuery.paddingOf(context).bottom),
        children: const [
          _TopBarSection(),
          Gap(16),
          _ScopeChipsSection(),
          Gap(18),
          _LiveScanningSection(),
          _HeroReclaimableCard(),
          Gap(24),
          _QuickToolsSection(),
          Gap(28),
          _MoreToolsSection(),
          Gap(20),
          _TrashGuaranteeCard(),
          Gap(12),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// 1. TOP BAR SECTION (Page 6 & 7)
// ---------------------------------------------------------
class _TopBarSection extends StatelessWidget {
  const _TopBarSection();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : AppColors.ink;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              // SnapSweep Logo badge
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.violet.withValues(alpha: 0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/app_logo.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const Gap(10),
              Flexible(
                child: Text(
                  "SnapSweep",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.heading20(
                    color: primaryTextColor,
                  ).copyWith(fontSize: 22),
                ),
              ),
            ],
          ),
        ),
        const Gap(8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Trash / Recovery quick button
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                context.push('/trash');
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.ink2 : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lilac2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: isDark ? const Color(0xFFFF7A88) : AppColors.trashRedLight,
                  ),
                ),
              ),
            ),
            const Gap(8),
            Selector<ScanProvider, bool>(
              selector: (_, p) => p.isLoading,
              builder: (context, isLoading, _) {
                return GestureDetector(
                  onTap: isLoading ? null : () {
                    HapticFeedback.selectionClick();
                    context.read<ScanProvider>().scan(force: true);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.ink2 : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lilac2,
                      ),
                    ),
                    child: Center(
                      child: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.violet,
                              ),
                            )
                          : Icon(
                              Icons.refresh_rounded,
                              size: 20,
                              color: isDark ? Colors.white : AppColors.ink,
                            ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// 2. SCOPE CHIPS (Page 6 & 7)
// ---------------------------------------------------------
class _ScopeChipsSection extends StatelessWidget {
  const _ScopeChipsSection();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Selector<ScanProvider, ({bool isLoading, ScanScope scope})>(
      selector: (_, p) => (isLoading: p.isLoading, scope: p.scanScope),
      builder: (context, data, _) {
        return SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ScanScope.values.length,
            separatorBuilder: (_, _) => const Gap(8),
            itemBuilder: (context, index) {
              final scope = ScanScope.values[index];
              final isSelected = scope == data.scope;

              return GestureDetector(
                onTap: data.isLoading ? null : () {
                  HapticFeedback.selectionClick();
                  context.read<ScanProvider>().setScanScope(scope);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.violet
                        : (isDark ? AppColors.ink2 : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.violet
                          : (isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.lilac2.withValues(alpha: 0.5)),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      scope.label,
                      style: AppTypography.meta13(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? const Color(0xFFA49EBA) : AppColors.ink),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------
// 3. LIVE SCANNING PROGRESS SECTION (When scan is active)
// ---------------------------------------------------------
class _LiveScanningSection extends StatelessWidget {
  const _LiveScanningSection();

  @override
  Widget build(BuildContext context) {
    return Selector<ScanProvider, ({bool isLoading, double progress, String message, List<AssetEntity> recent})>(
      selector: (_, p) => (
        isLoading: p.isLoading,
        progress: p.progress,
        message: p.scanStatusMessage,
        recent: List.of(p.recentScanned),
      ),
      builder: (context, data, _) {
        if (!data.isLoading) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = isDark ? AppColors.ink2 : Colors.white;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.violet.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      data.message.isEmpty ? "Scanning gallery..." : data.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body15(
                        color: isDark ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Gap(8),
                  Text(
                    "${(data.progress * 100).toInt()}%",
                    style: AppTypography.heading20(color: AppColors.violet),
                  ),
                ],
              ),
              const Gap(10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: data.progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: isDark ? const Color(0xFF281357) : AppColors.lilac,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              ),
              if (data.recent.isNotEmpty) ...[
                const Gap(12),
                SizedBox(
                  height: 36,
                  child: Row(
                    children: data.recent.take(6).map((asset) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AssetEntityImage(
                            asset,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            thumbnailSize: const ThumbnailSize.square(80),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------
// 4. HERO RECLAIMABLE STORAGE CARD (Page 6 / 36)
// ---------------------------------------------------------
class _HeroReclaimableCard extends StatelessWidget {
  const _HeroReclaimableCard();

  @override
  Widget build(BuildContext context) {
    return Selector<ScanProvider, ({
      bool isLoading,
      int totalItems,
      String reclaimableSize,
      String dupSize,
      String vidSize,
      String otherSize,
      int smartCleanBytes,
    })>(
      selector: (_, p) {
        final totalReclaim = p.duplicateSize + p.largeVideosSize;
        return (
          isLoading: p.isLoading,
          totalItems: p.totalDuplicateCount + p.largeVideos.length,
          reclaimableSize: totalReclaim > 0
              ? AppUtils.formatBytes(totalReclaim)
              : p.formattedSmartCleanSize,
          dupSize: p.formattedDuplicateSize,
          vidSize: p.formattedLargeVideosSize,
          otherSize: p.formattedBlurrySize,
          smartCleanBytes: p.smartCleanSize,
        );
      },
      builder: (context, data, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final heroBg = isDark ? const Color(0xFF0F0426) : AppColors.ink;

        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: heroBg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top label and graphic placeholder
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "RECLAIMABLE NOW",
                          style: AppTypography.caption11(
                            color: AppColors.lilac,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Gap(8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            data.isLoading ? "..." : data.reclaimableSize,
                            style: AppTypography.display68(
                              color: Colors.white,
                            ).copyWith(fontSize: 48),
                          ),
                        ),
                        const Gap(4),
                        Text(
                          data.isLoading
                              ? "Analyzing gallery..."
                              : "${data.totalItems} items to review",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body15(
                            color: const Color(0xFFA49EBA),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(12),
                  // Stylized Illustration Placeholder (Page 1 / Page 6)
                  Container(
                    width: 76,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.lilac,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: 32,
                            decoration: const BoxDecoration(
                              color: AppColors.violet,
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Gap(20),

              // Segment Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Container(
                        height: 6,
                        color: AppColors.violet,
                      ),
                    ),
                    const Gap(3),
                    Expanded(
                      flex: 5,
                      child: Container(
                        height: 6,
                        color: AppColors.gold,
                      ),
                    ),
                    const Gap(3),
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 6,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),

              const Gap(10),

              // Segment Sub-labels
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Duplicates ${data.dupSize}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.meta13(
                        color: const Color(0xFFA49EBA),
                      ),
                    ),
                  ),
                  const Gap(6),
                  Expanded(
                    child: Text(
                      "Videos ${data.vidSize}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.meta13(
                        color: const Color(0xFFA49EBA),
                      ),
                    ),
                  ),
                  const Gap(6),
                  Expanded(
                    child: Text(
                      "Other ${data.otherSize}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: AppTypography.meta13(
                        color: const Color(0xFFA49EBA),
                      ),
                    ),
                  ),
                ],
              ),

              const Gap(22),

              // Review and Clean Gold CTA Button (The One Thing to Act On)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    if (data.smartCleanBytes > 0) {
                      context.push('/smart-clean');
                    } else {
                      context.push('/duplicates');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.ink,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Review and clean",
                        style: AppTypography.button15(color: AppColors.ink)
                            .copyWith(fontSize: 16),
                      ),
                      const Gap(10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "SAFE",
                          style: AppTypography.caption11(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------
// 5. QUICK TOOLS SECTION (Page 6 / 36)
// ---------------------------------------------------------
class _QuickToolsSection extends StatelessWidget {
  const _QuickToolsSection();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : AppColors.ink;

    return Selector<ScanProvider, ({
      bool isLoading,
      int dupCount,
      String dupSize,
      int burstCount,
      String burstSize,
      int blurCount,
      String blurSize,
    })>(
      selector: (_, p) => (
        isLoading: p.isLoading,
        dupCount: p.totalDuplicateCount,
        dupSize: p.formattedDuplicateSize,
        burstCount: p.similarGroups.length,
        burstSize: p.formattedSimilarSize,
        blurCount: p.blurryPhotos.length,
        blurSize: p.formattedBlurrySize,
      ),
      builder: (context, data, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Quick tools",
                  style: AppTypography.heading20(color: primaryTextColor),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF281357) : AppColors.lilac,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "8 tools",
                    style: AppTypography.caption11(
                      color: isDark ? AppColors.lilac : AppColors.violet,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(14),

            // 2x2 Grid for Exact Duplicates & Burst
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Exact Duplicates (Solid Violet Card)
                  Expanded(
                    child: _buildSolidToolCard(
                      bg: AppColors.violet,
                      textColor: Colors.white,
                      subtextColor: Colors.white.withValues(alpha: 0.8),
                      icon: Icons.copy_rounded,
                      number: data.isLoading ? "..." : "${data.dupCount}",
                      title: "Exact duplicates",
                      subtitle: "${data.dupSize} safe to free",
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push('/duplicates');
                      },
                    ),
                  ),
                  const Gap(12),

                  // Burst Best Shot (Solid Gold Card)
                  Expanded(
                    child: _buildSolidToolCard(
                      bg: AppColors.gold,
                      textColor: AppColors.ink,
                      subtextColor: AppColors.ink.withValues(alpha: 0.75),
                      icon: Icons.burst_mode_rounded,
                      number: data.isLoading ? "..." : "${data.burstCount}",
                      title: "Burst - best shot",
                      subtitle: "${data.burstSize} to review",
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push('/burst-cleaner');
                      },
                    ),
                  ),
                ],
              ),
            ),

            const Gap(12),

            // Blurry Photos (Wide Card)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                context.push('/blurry-photos');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.ink2 : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.lilac2.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF281357) : AppColors.lilac,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.blur_on_rounded,
                        size: 24,
                        color: AppColors.violet,
                      ),
                    ),
                    const Gap(14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Blurry photos",
                            style: AppTypography.heading20(
                              color: primaryTextColor,
                            ).copyWith(fontSize: 16),
                          ),
                          const Gap(2),
                          Text(
                            data.isLoading
                                ? "Analyzing camera roll..."
                                : "${data.blurCount} shots | ${data.blurSize} to review",
                            style: AppTypography.meta13(
                              color: isDark
                                  ? const Color(0xFFA49EBA)
                                  : const Color(0xFF5F567A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? const Color(0xFFA49EBA) : const Color(0xFF5F567A),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSolidToolCard({
    required Color bg,
    required Color textColor,
    required Color subtextColor,
    required IconData icon,
    required String number,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(minHeight: 162),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 24, color: textColor),
                Icon(Icons.arrow_outward_rounded, size: 20, color: textColor),
              ],
            ),
            const Gap(10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    number,
                    style: AppTypography.title30(color: textColor).copyWith(fontSize: 28),
                  ),
                ),
                const Gap(2),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body15(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    style: AppTypography.caption11(color: subtextColor, letterSpacing: 0),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 6. MORE TOOLS SECTION (Page 7 / 37)
// ---------------------------------------------------------
class _MoreToolsSection extends StatelessWidget {
  const _MoreToolsSection();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : AppColors.ink;

    return Selector<ScanProvider, ({
      bool isLoading,
      int vidCount,
      String vidSize,
      int socialCount,
      String socialSize,
      int screenshotCount,
      String screenshotSize,
      int totalItems,
      String totalSize,
    })>(
      selector: (_, p) => (
        isLoading: p.isLoading,
        vidCount: p.largeVideos.length,
        vidSize: p.formattedLargeVideosSize,
        socialCount: p.categories['Social & WhatsApp']?.length ?? 0,
        socialSize: p.getFormattedCategorySize('Social & WhatsApp'),
        screenshotCount: p.categories['Screenshots']?.length ?? 0,
        screenshotSize: p.getFormattedCategorySize('Screenshots'),
        totalItems: p.allScreenshots.length,
        totalSize: p.formattedTotalSize,
      ),
      builder: (context, data, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "CLEANER",
                      style: AppTypography.caption11(
                        color: isDark ? const Color(0xFFA49EBA) : const Color(0xFF5F567A),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      "More tools",
                      style: AppTypography.heading20(color: primaryTextColor),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF281357) : AppColors.lilac,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "6 OF 8",
                    style: AppTypography.caption11(
                      color: isDark ? AppColors.lilac : AppColors.violet,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(14),

            // Row 1: Large videos & Compress and save
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Large videos (Deep Ink card)
                  Expanded(
                    child: _buildMoreToolCard(
                      context: context,
                      bg: isDark ? const Color(0xFF0F0426) : AppColors.ink,
                      textColor: Colors.white,
                      subtextColor: const Color(0xFFA49EBA),
                      iconContainerBg: AppColors.gold,
                      iconColor: AppColors.ink,
                      icon: Icons.videocam_rounded,
                      number: data.isLoading ? "..." : "${data.vidCount}",
                      title: "Large videos",
                      subtitle: "${data.vidSize} total",
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push('/large-videos');
                      },
                    ),
                  ),
                  const Gap(12),

                  // Compress and save (Lilac Tinted Card)
                  Expanded(
                    child: _buildMoreToolCard(
                      context: context,
                      bg: isDark ? const Color(0xFF200F48) : AppColors.lilac,
                      textColor: isDark ? Colors.white : AppColors.ink,
                      subtextColor: isDark ? const Color(0xFFA49EBA) : const Color(0xFF5F567A),
                      iconContainerBg: AppColors.violet,
                      iconColor: Colors.white,
                      icon: Icons.compress_rounded,
                      number: "80%",
                      title: "Compress and save",
                      subtitle: "Up to, per video",
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push('/media-compressor');
                      },
                    ),
                  ),
                ],
              ),
            ),

            const Gap(12),

            // Row 2: WhatsApp & social + Screenshot expiry
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // WhatsApp and social (Violet Card)
                  Expanded(
                    child: _buildMoreToolCard(
                      context: context,
                      bg: AppColors.violet,
                      textColor: Colors.white,
                      subtextColor: Colors.white.withValues(alpha: 0.8),
                      iconContainerBg: Colors.white,
                      iconColor: AppColors.violet,
                      icon: Icons.chat_bubble_rounded,
                      number: data.isLoading ? "..." : "${data.socialCount}",
                      title: "WhatsApp and social",
                      subtitle: "${data.socialSize} to clean",
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push('/messaging-cleaner');
                      },
                    ),
                  ),
                  const Gap(12),

                  // Screenshot expiry (Light Card / Ink2)
                  Expanded(
                    child: _buildMoreToolCard(
                      context: context,
                      bg: isDark ? AppColors.ink2 : Colors.white,
                      textColor: isDark ? Colors.white : AppColors.ink,
                      subtextColor: isDark ? const Color(0xFFA49EBA) : const Color(0xFF5F567A),
                      iconContainerBg: AppColors.gold,
                      iconColor: AppColors.ink,
                      icon: Icons.phone_android_rounded,
                      number: data.isLoading ? "..." : "${data.screenshotCount}",
                      title: "Screenshot expiry",
                      subtitle: "Older than 30 days",
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push('/screenshot-cleaner');
                      },
                      hasBorder: !isDark,
                    ),
                  ),
                ],
              ),
            ),

            const Gap(12),

            // Storage Time Machine (Wide Card)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                context.push('/storage-timeline');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.ink2 : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.lilac2.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F0426) : AppColors.ink,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.schedule_rounded,
                        size: 22,
                        color: AppColors.gold,
                      ),
                    ),
                    const Gap(14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Storage time machine",
                            style: AppTypography.heading20(
                              color: primaryTextColor,
                            ).copyWith(fontSize: 16),
                          ),
                          const Gap(2),
                          Text(
                            "Monthly history and peaks",
                            style: AppTypography.meta13(
                              color: isDark
                                  ? const Color(0xFFA49EBA)
                                  : const Color(0xFF5F567A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? const Color(0xFFA49EBA) : const Color(0xFF5F567A),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMoreToolCard({
    required BuildContext context,
    required Color bg,
    required Color textColor,
    required Color subtextColor,
    required Color iconContainerBg,
    required Color iconColor,
    required IconData icon,
    required String number,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool hasBorder = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(minHeight: 162),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: hasBorder
              ? Border.all(color: AppColors.lilac2.withValues(alpha: 0.5))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconContainerBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                Icon(Icons.arrow_outward_rounded, size: 18, color: textColor),
              ],
            ),
            const Gap(10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    number,
                    style: AppTypography.title30(color: textColor).copyWith(fontSize: 28),
                  ),
                ),
                const Gap(2),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body15(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    style: AppTypography.caption11(color: subtextColor, letterSpacing: 0),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 7. TRASH GUARANTEE CARD (Page 7 / 37)
// ---------------------------------------------------------
class _TrashGuaranteeCard extends StatelessWidget {
  const _TrashGuaranteeCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/trash');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF281357) : AppColors.lilac,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.violet.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 20,
              color: AppColors.violet,
            ),
            const Gap(12),
            Expanded(
              child: Text(
                "Every delete moves to Trash. Restore within 30 days.",
                style: AppTypography.meta13(
                  color: isDark ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Gap(8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? AppColors.lilac : AppColors.violet,
            ),
          ],
        ),
      ),
    );
  }
}
