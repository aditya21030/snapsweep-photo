import 'package:flutter/material.dart';

class AppColors {
  // --- Solid 4-Color Core (Pulled from Logo) ---
  static const Color ink = Color(0xFF12052D); // Deep Ink (Canvas in dark, primary text in light)
  static const Color ink2 = Color(0xFF1D0C47); // Dark Surface / Elevated cards
  static const Color inkLight = Color(0xFF281357); // Subtle card highlight in dark mode

  static const Color violet = Color(0xFF6D2DF7); // Primary Brand Violet
  static const Color violetDeep = Color(0xFF5F1FEF); // Deep Violet for active surfaces
  static const Color violetMuted = Color(0xFF8655F9); // Lighter violet for accents

  static const Color gold = Color(0xFFFCC80E); // Action Gold ("One thing to act on: best shot, keep, clean now")
  static const Color goldDark = Color(0xFFE5B405); // Gold pressed/active state

  static const Color lavender = Color(0xFFF6F5FC); // Light Canvas Background
  static const Color lilac = Color(0xFFE9E0FF); // Light Chip / Badge / Pill surface
  static const Color lilac2 = Color(0xFFD9C9FF); // Border / Selection Ring / Subtle divider

  // --- Destructive / Action Colors ---
  static const Color trashRedLight = Color(0xFFD92B45); // Light mode trash action
  static const Color trashRedDark = Color(0xFFFF7A88); // Dark mode trash action

  // --- Backward Compatibility Aliases ---
  static const Color primary = violet;
  static const Color onPrimary = Colors.white;
  static const Color secondary = gold;
  static const Color tertiary = lilac;
  static const Color error = trashRedLight;

  static const Color backgroundLight = lavender;
  static const Color surfaceLight = Colors.white;

  static const Color backgroundDark = ink;
  static const Color surfaceDark = ink2;

  // Semantic category card backgrounds
  static const Color catViolet = violet;
  static const Color catInk = ink;
  static const Color catGold = gold;
  static const Color catLilac = lilac;

  // Adaptive helper methods
  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? ink2 : Colors.white;
  }

  static Color scaffoldBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? ink : lavender;
  }

  static Color cardBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : lilac2.withValues(alpha: 0.5);
  }

  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFFFFF)
        : ink;
  }

  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFA49EBA)
        : const Color(0xFF5F567A);
  }

  static Color textMuted(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF756F8E)
        : const Color(0xFF8E88A6);
  }

  static Color trashRed(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? trashRedDark
        : trashRedLight;
  }
}
