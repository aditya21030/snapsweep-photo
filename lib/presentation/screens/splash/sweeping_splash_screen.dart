import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class SweepingSplashScreen extends StatefulWidget {
  final VoidCallback onAnimationComplete;

  const SweepingSplashScreen({super.key, required this.onAnimationComplete});

  @override
  State<SweepingSplashScreen> createState() => _SweepingSplashScreenState();
}

class _SweepingSplashScreenState extends State<SweepingSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );

    _scanAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) widget.onAnimationComplete();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.ink : AppColors.lavender;
    final primaryTextColor = isDark ? Colors.white : AppColors.ink;
    final secondaryTextColor = isDark
        ? const Color(0xFFA49EBA)
        : const Color(0xFF5F567A);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Viewfinder Scanner Frame
              Center(
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Viewfinder Corners
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ViewfinderCornersPainter(
                            color: isDark
                                ? const Color(0xFF281357)
                                : AppColors.lilac,
                          ),
                        ),
                      ),

                      // Center Squircle Icon
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.ink2 : AppColors.ink,
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.violet.withValues(
                                alpha: isDark ? 0.35 : 0.18,
                              ),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Stacked Photo Graphic
                            Transform.rotate(
                              angle: -0.08,
                              child: Container(
                                width: 70,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: AppColors.violet,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            Transform.rotate(
                              angle: 0.05,
                              child: Container(
                                width: 76,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    // Purple mountain shape
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        height: 30,
                                        decoration: const BoxDecoration(
                                          color: AppColors.violet,
                                          borderRadius: BorderRadius.vertical(
                                            bottom: Radius.circular(14),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Golden 4-point sparkle star
                                    Positioned(
                                      top: 8,
                                      right: 12,
                                      child: Icon(
                                        Icons.auto_awesome,
                                        size: 16,
                                        color: AppColors.gold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Scanning Yellow Laser Line
                            AnimatedBuilder(
                              animation: _scanAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, _scanAnimation.value * 45),
                                  child: Container(
                                    width: 170,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: AppColors.gold,
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.gold.withValues(
                                            alpha: 0.8,
                                          ),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Gap(36),

              // Title
              Text(
                "SnapSweep",
                style: AppTypography.title30(
                  color: primaryTextColor,
                ).copyWith(fontSize: 34),
              ),

              const Gap(8),

              // Subtitle
              Text(
                "Clean your photos smartly",
                style: AppTypography.body15(
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(flex: 3),

              // Page Dots Indicator (Active Gold dash, inactive dots)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const Gap(6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2E195E) : AppColors.lilac,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Gap(6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2E195E) : AppColors.lilac,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),

              const Gap(18),

              // Privacy Tagline
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 16,
                    color: secondaryTextColor,
                  ),
                  const Gap(6),
                  Text(
                    'Gallery analysis stays on-device.',
                    style: AppTypography.meta13(
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const Gap(12),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Painter for Viewfinder Corners
class _ViewfinderCornersPainter extends CustomPainter {
  final Color color;

  _ViewfinderCornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 32.0;
    const radius = 18.0;

    // Top-Left
    final pathTL = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, radius)
      ..arcToPoint(
        const Offset(radius, 0),
        radius: const Radius.circular(radius),
      )
      ..lineTo(cornerLength, 0);
    canvas.drawPath(pathTL, paint);

    // Top-Right
    final pathTR = Path()
      ..moveTo(size.width - cornerLength, 0)
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(
        Offset(size.width, radius),
        radius: const Radius.circular(radius),
      )
      ..lineTo(size.width, cornerLength);
    canvas.drawPath(pathTR, paint);

    // Bottom-Left
    final pathBL = Path()
      ..moveTo(0, size.height - cornerLength)
      ..lineTo(0, size.height - radius)
      ..arcToPoint(
        Offset(radius, size.height),
        radius: const Radius.circular(radius),
      )
      ..lineTo(cornerLength, size.height);
    canvas.drawPath(pathBL, paint);

    // Bottom-Right
    final pathBR = Path()
      ..moveTo(size.width - cornerLength, size.height)
      ..lineTo(size.width - radius, size.height)
      ..arcToPoint(
        Offset(size.width, size.height - radius),
        radius: const Radius.circular(radius),
      )
      ..lineTo(size.width, size.height - cornerLength);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderCornersPainter oldDelegate) =>
      oldDelegate.color != color;
}
