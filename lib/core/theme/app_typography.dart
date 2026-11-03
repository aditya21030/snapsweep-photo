import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  // Display 68 - Large numbers, storage metrics (Bricolage Grotesque 800)
  static TextStyle display68({Color? color, double height = 1.05}) {
    return GoogleFonts.bricolageGrotesque(
      fontSize: 68,
      fontWeight: FontWeight.w800,
      letterSpacing: -2.0,
      height: height,
      color: color,
    );
  }

  // Display 48 - Intermediate metrics (e.g., 68% progress ring)
  static TextStyle display48({Color? color, double height = 1.1}) {
    return GoogleFonts.bricolageGrotesque(
      fontSize: 48,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.5,
      height: height,
      color: color,
    );
  }

  // Title 30 - Screen headers, main category titles
  static TextStyle title30({Color? color, double height = 1.15}) {
    return GoogleFonts.bricolageGrotesque(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      height: height,
      color: color,
    );
  }

  // Heading 20 - Card headers, subheadings
  static TextStyle heading20({Color? color, double height = 1.2}) {
    return GoogleFonts.bricolageGrotesque(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      height: height,
      color: color,
    );
  }

  // Subheading 17 - Intermediate section titles
  static TextStyle subheading17({Color? color, double height = 1.25}) {
    return GoogleFonts.bricolageGrotesque(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: height,
      color: color,
    );
  }

  // Body 15 - Descriptions, explanations, standard labels (DM Sans 400-500)
  static TextStyle body15({
    Color? color,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.35,
  }) {
    return GoogleFonts.dmSans(
      fontSize: 15,
      fontWeight: fontWeight,
      letterSpacing: -0.1,
      height: height,
      color: color,
    );
  }

  // Button 15 - Primary action buttons (DM Sans 700)
  static TextStyle button15({Color? color, double height = 1.1}) {
    return GoogleFonts.dmSans(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
      height: height,
      color: color,
    );
  }

  // Meta 13 - Counts, secondary metadata, chips (DM Sans 500-600)
  static TextStyle meta13({
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    double height = 1.3,
  }) {
    return GoogleFonts.dmSans(
      fontSize: 13,
      fontWeight: fontWeight,
      letterSpacing: 0.0,
      height: height,
      color: color,
    );
  }

  // Caption 11 - Overlines, uppercase tags (DM Sans 700)
  static TextStyle caption11({
    Color? color,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = 1.0,
  }) {
    return GoogleFonts.dmSans(
      fontSize: 11,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }
}
