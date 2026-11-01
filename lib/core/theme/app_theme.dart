import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surfaceLight,
      onSurface: Color(0xFF121216),
      onSurfaceVariant: Color(0xFF555566),
      surfaceContainerHighest: Color(0xFFEDEEF6),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: const Color(0xFF121216),
        displayColor: const Color(0xFF121216),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: Color(0xFF121216),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF121216)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surfaceDark,
      onSurface: Color(0xFFF5F5FA),
      onSurfaceVariant: Color(0xFFB4B4C4),
      surfaceContainerHighest: Color(0xFF282832),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: const Color(0xFFF5F5FA),
        displayColor: const Color(0xFFF5F5FA),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: Color(0xFFF5F5FA),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFF5F5FA)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
