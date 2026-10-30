import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Text styles. Sizes are in logical pixels and scale with the system font
/// size through [MediaQuery.textScaler].
abstract final class AppTextStyles {
  static const String fontFamily = 'Inter';

  static TextTheme textTheme(AppColors c) {
    return TextTheme(
      displaySmall: _style(32, FontWeight.w700, c.textPrimary, -0.5),
      headlineMedium: _style(26, FontWeight.w700, c.textPrimary, -0.4),
      headlineSmall: _style(22, FontWeight.w700, c.textPrimary, -0.3),
      titleLarge: _style(20, FontWeight.w700, c.textPrimary, -0.2),
      titleMedium: _style(16, FontWeight.w600, c.textPrimary, 0),
      titleSmall: _style(14, FontWeight.w600, c.textPrimary, 0),
      bodyLarge: _style(16, FontWeight.w400, c.textPrimary, 0),
      bodyMedium: _style(14, FontWeight.w400, c.textSecondary, 0),
      bodySmall: _style(12, FontWeight.w400, c.textSecondary, 0),
      labelLarge: _style(14, FontWeight.w600, c.textPrimary, 0.1),
      labelMedium: _style(12, FontWeight.w500, c.textSecondary, 0.2),
      labelSmall: _style(11, FontWeight.w500, c.textSecondary, 0.3),
    );
  }

  /// Monospaced digits for elapsed/remaining times, so they don't jitter.
  static TextStyle timecode(AppColors c) => _style(
    12,
    FontWeight.w500,
    c.textSecondary,
    0,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static TextStyle _style(
    double size,
    FontWeight weight,
    Color color,
    double letterSpacing,
  ) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: 1.3,
    );
  }
}
