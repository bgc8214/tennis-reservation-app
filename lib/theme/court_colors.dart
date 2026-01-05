import 'package:flutter/cupertino.dart';

/// Tennis court-inspired color palette
/// 테니스 코트에서 영감받은 색상 팔레트
class CourtColors {
  // Primary colors inspired by different court surfaces

  /// Clay court's warm terra cotta - 클레이 코트의 따뜻한 테라코타
  static const clay = Color(0xFFE67E50);
  static const clayLight = Color(0xFFFF9E7A);
  static const clayDark = Color(0xFFB85C3A);

  /// Grass court's vibrant green - 잔디 코트의 생동감 있는 그린
  static const grass = Color(0xFF2ECC71);
  static const grassLight = Color(0xFF58D68D);
  static const grassDark = Color(0xFF229954);

  /// Hard court's deep navy blue - 하드 코트의 진한 네이비
  static const hardCourt = Color(0xFF1A2332);
  static const hardCourtLight = Color(0xFF2C3E50);
  static const hardCourtDark = Color(0xFF0F1419);

  /// Tennis ball's fluorescent yellow-green - 테니스볼의 형광 옐로우그린
  static const ballYellow = Color(0xFFCCFF00);
  static const ballYellowLight = Color(0xFFE0FF66);
  static const ballYellowDark = Color(0xFFAACC00);

  /// Court line's crisp white - 코트 라인의 선명한 화이트
  static const courtLine = Color(0xFFFAFAFA);
  static const courtLineGrey = Color(0xFFE8E8E8);

  /// Urgent/important indicator vibrant red - 긴급/중요 표시용
  static const urgent = Color(0xFFFF3B30);
  static const urgentLight = Color(0xFFFF6B60);
  static const urgentDark = Color(0xFFCC2F26);

  /// Warning yellow - 경고 옐로우
  static const warning = Color(0xFFFFCC00);
  static const warningLight = Color(0xFFFFDD33);
  static const warningDark = Color(0xFFCCA300);

  // Neutral colors for backgrounds and text

  /// Dark mode background
  static const darkBg = Color(0xFF0A0E14);
  static const darkBgSecondary = Color(0xFF151B23);
  static const darkBgTertiary = Color(0xFF1F2832);

  /// Light mode background
  static const lightBg = Color(0xFFF8F9FA);
  static const lightBgSecondary = Color(0xFFFFFFFF);
  static const lightBgTertiary = Color(0xFFF0F2F5);

  /// Text colors
  static const textDark = Color(0xFF1A1A1A);
  static const textLight = Color(0xFFFAFAFA);
  static const textGrey = Color(0xFF8E8E93);

  // Gradient combinations

  static const LinearGradient urgentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [urgent, urgentLight],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [warning, warningLight],
  );

  static const LinearGradient grassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [grass, grassLight],
  );

  static const LinearGradient ballGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ballYellow, ballYellowLight],
  );

  static const RadialGradient ballRadialGradient = RadialGradient(
    colors: [ballYellowLight, ballYellow, ballYellowDark],
    stops: [0.0, 0.7, 1.0],
  );

  /// Get color based on remaining days
  /// 남은 일수에 따른 색상 반환
  static Color getColorForDays(int days) {
    if (days <= 1) {
      return urgent;
    } else if (days <= 3) {
      return urgentLight;
    } else if (days <= 7) {
      return warning;
    } else if (days <= 14) {
      return grass;
    } else {
      return textGrey;
    }
  }

  /// Get gradient based on remaining days
  /// 남은 일수에 따른 그라데이션 반환
  static LinearGradient getGradientForDays(int days) {
    if (days <= 1) {
      return urgentGradient;
    } else if (days <= 7) {
      return warningGradient;
    } else {
      return grassGradient;
    }
  }
}
