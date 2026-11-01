import 'package:flutter/material.dart';

/// سلّم الخطوط (Tajawal) بأوزان وأحجام متناسقة.
/// يمكن تغيير family إلى أي خط تريده عبر تعديل ثابت family.
class AppTypography {
  const AppTypography._();

  /// عائلة الخط المستخدمة في التطبيق (Tajawal تدعم العربية والإنجليزية).
  static const String family = 'Tajawal';

  static TextTheme textTheme({
    required Color primaryText,
    required Color secondaryText,
  }) {
    TextStyle base(
      double size,
      FontWeight weight, {
      double height = 1.45,
      Color? color,
      double spacing = 0,
    }) {
      return TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        color: color ?? primaryText,
      );
    }

    return TextTheme(
      displayLarge: base(44, FontWeight.w800, height: 1.15),
      displayMedium: base(38, FontWeight.w800, height: 1.15),
      displaySmall: base(32, FontWeight.w800, height: 1.18),
      headlineLarge: base(28, FontWeight.w800, height: 1.2),
      headlineMedium: base(25, FontWeight.w800, height: 1.22),
      headlineSmall: base(22, FontWeight.w800, height: 1.25),
      titleLarge: base(19, FontWeight.w800, height: 1.3),
      titleMedium: base(16, FontWeight.w700, height: 1.35),
      titleSmall: base(14.5, FontWeight.w700, height: 1.4),
      bodyLarge: base(15, FontWeight.w400, height: 1.6),
      bodyMedium: base(14, FontWeight.w400, height: 1.6),
      bodySmall: base(12.5, FontWeight.w400, height: 1.55),
      labelLarge: base(14, FontWeight.w700, height: 1.3),
      labelMedium: base(12, FontWeight.w700, height: 1.3),
      labelSmall: base(11, FontWeight.w600, height: 1.3),
    ).apply(
      bodyColor: primaryText,
      displayColor: primaryText,
    );
  }

  /// نمط الأرقام المالية: أرقام جدولية واضحة.
  static TextStyle numeric({
    required Color color,
    double size = 18,
    FontWeight weight = FontWeight.w800,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.25,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }
}
