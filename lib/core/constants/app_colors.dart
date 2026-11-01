import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2575FC); // Branded Blue
  static const Color onPrimary = Colors.white;
  static const Color secondary = Color(0xFF4F6BED); // Bright, high-contrast Indigo-Blue
  static const Color tertiary = Color(0xFF00C6FF); // Cyan-Blue Accent

  static const Color error = Color(0xFFE53935);

  // Custom colors for specific cards
  static const Color duplicateCardStart = Color(0xD8FF4545);
  static const Color duplicateCardEnd = Color(0xFFFF7A7A);

  static const Color similarCardStart = Color(0xFF4568FF);
  static const Color similarCardEnd = Color(0xFF7A94FF);

  // Category Gradients
  static const Color cat1Start = Color(0xFFFF9966);
  static const Color cat1End = Color(0xFFFF5E62);

  static const Color cat2Start = Color(0xFF8E2DE2);
  static const Color cat2End = Color(0xFF4A00E0);

  static const Color cat3Start = Color(0xFF11998E);
  static const Color cat3End = Color(0xFF38EF7D);

  static const Color cat4Start = Color(0xFFF2994A);
  static const Color cat4End = Color(0xFFF2C94C);

  static const Color backgroundLight = Color(0xFFF8F9FE);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  static const Color backgroundDark = Color(0xFF121216);
  static const Color surfaceDark = Color(0xFF1E1E24);

  // High-contrast accessible text colors for both Dark and Light modes
  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF5F5FA)
        : const Color(0xFF121216);
  }

  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB4B4C4)
        : const Color(0xFF555566);
  }

  static Color textMuted(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF888898)
        : const Color(0xFF7A7A8A);
  }
}
