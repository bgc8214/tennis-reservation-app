import 'package:flutter/cupertino.dart';

/// Typography system for Court Alarm app
/// Emphasizes clarity, energy, and athletic aesthetics
class CourtTypography {
  // Display styles - for headers and important information

  static const TextStyle display1 = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.0,
    height: 1.1,
  );

  static const TextStyle display2 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle display3 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
  );

  // Headline styles - for section headers

  static const TextStyle headline1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle headline2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.3,
  );

  static const TextStyle headline3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // Body styles - for general text

  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.1,
  );

  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.1,
  );

  static const TextStyle body3 = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.2,
  );

  // Timer/Counter styles - monospaced for digital clock feel

  static const TextStyle timer1 = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    letterSpacing: 2.0,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle timer2 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle timer3 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // Label styles - for tags and small labels

  static const TextStyle label1 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.2,
  );

  static const TextStyle label2 = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.2,
  );

  static const TextStyle label3 = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.2,
  );

  // Button styles

  static const TextStyle button1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    height: 1.2,
  );

  static const TextStyle button2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.2,
  );

  // Caption styles

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    height: 1.3,
  );

  static const TextStyle captionBold = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.3,
  );
}
