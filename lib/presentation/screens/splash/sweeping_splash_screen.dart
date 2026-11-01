import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import 'package:gap/gap.dart';

class SweepingSplashScreen extends StatefulWidget {
  final VoidCallback onAnimationComplete;

  const SweepingSplashScreen({super.key, required this.onAnimationComplete});

  @override
  State<SweepingSplashScreen> createState() => _SweepingSplashScreenState();
}

class _SweepingSplashScreenState extends State<SweepingSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    // Simple 0 to 1 sweep
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward().then((_) {
      widget.onAnimationComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Shared text widget to ensure exact overlay alignment
    final textContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Gap(40),
        Text(
          AppStrings.appName,
          style: GoogleFonts.outfit(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2.0,
          ),
        ),
        const Gap(10),
        Text(
          AppStrings.tagline,
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: Colors.white, // Keep base white, opacity handled by layer
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.secondary,
              AppColors.primary,
            ],
          ),
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Layer 1: "Dirty" / Dim Text (Always visible)
              Opacity(
                opacity: 0.2, // Very dim
                child: textContent,
              ),

              // Layer 2: "Clean" / Bright Text (Revealed by sweep)
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        stops: [
                          _animation.value,      // Clean part ends here
                          _animation.value + 0.1, // Fade transition
                        ],
                        colors: const [
                          Colors.white,        // Reveal (Clean)
                          Colors.transparent,  // Hidden (Dirty)
                        ],
                        tileMode: TileMode.clamp,
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.srcIn, // Show source (text) only where gradient is white
                    child: textContent,
                  );
                },
              ),
              
              // The Broom Icon
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  // Map 0.0->1.0 to -1.0->1.0 (Left to Right screen edge)
                  // Adjust range slightly to start/end off-screen if needed
                  // Let's sweep slightly wider than the screen to ensure full entry/exit
                  final alignmentX = (_animation.value * 2.4) - 1.2; 
                  
                  return Align(
                    alignment: Alignment(alignmentX, 0.05), // Slightly lowered to match text baseline?
                    child: Transform.rotate(
                      angle: -0.5, // Tilted broom
                      child: const Icon(
                        Icons.cleaning_services_rounded,
                        size: 80, 
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
