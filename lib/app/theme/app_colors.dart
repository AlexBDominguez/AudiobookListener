import 'package:flutter/material.dart';

/// App color palette. Widgets read it with `context.colors` (see
/// `app_theme.dart`), so adding a light theme only means adding another
/// instance here.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.primary,
    required this.primarySoft,
    required this.onPrimary,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.error,
    required this.shadow,
  });

  static const dark = AppColors(
    background: Color(0xFF0B0A10),
    surface: Color(0xFF15131D),
    surfaceHigh: Color(0xFF1F1C2B),
    primary: Color(0xFF8B5CF6),
    primarySoft: Color(0xFFA78BFA),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFEC4899),
    textPrimary: Color(0xFFF4F2FA),
    textSecondary: Color(0xFF9A95AB),
    divider: Color(0xFF2A2638),
    error: Color(0xFFF87171),
    shadow: Color(0xFF000000),
  );

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color primary;
  final Color primarySoft;
  final Color onPrimary;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color error;
  final Color shadow;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? primary,
    Color? primarySoft,
    Color? onPrimary,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
    Color? error,
    Color? shadow,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      divider: divider ?? this.divider,
      error: error ?? this.error,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      error: Color.lerp(error, other.error, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}
