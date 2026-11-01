import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Spacing scale, in logical pixels.
///
/// A four-point scale keeps rhythm consistent and stops arbitrary padding
/// values accumulating across screens.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Minimum comfortable tap target, per Material accessibility guidance.
  static const double minTapTarget = 48;

  /// Bottom inset reserved for one-handed reach on tall phones.
  static const double thumbZoneReserve = 72;
}

/// Corner radii.
abstract final class AppRadius {
  static const double card = 10;
  static const double panel = 16;
  static const double sheet = 24;
  static const double pill = 999;
}

/// The application's dark theme.
///
/// Dark only, by design: the felt table is the product's identity and a light
/// variant would fight it. Text scaling and contrast still follow the
/// platform, so accessibility settings are respected.
abstract final class AppTheme {
  static ThemeData dark() {
    const ColorScheme scheme = ColorScheme.dark(
      primary: AppColors.gold,
      onPrimary: AppColors.textOnCard,
      secondary: AppColors.feltRaised,
      onSecondary: AppColors.textPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      onError: AppColors.textPrimary,
    );

    final TextTheme text = _textTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.feltDeep,
      canvasColor: AppColors.surface,
      // `cardTheme` is intentionally not set: its type changed from CardTheme
      // to CardThemeData across Flutter releases, and panels in this app are
      // styled directly (see AppPanel) rather than through Material Card.
      textTheme: text,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimary,
        // `titleTextStyle` is deliberately not set. Material 3 already defaults
        // it to `textTheme.titleLarge`, but to the *merged* one: ThemeData
        // merges the typography defaults under the styles below, which is where
        // the font family comes from. Passing the raw `text.titleLarge` here
        // skipped that merge, so app bar titles fell back to the platform font
        // while every other string used the themed one -- invisible on Android,
        // a San Francisco title over Roboto body text on iOS.
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.goldDim,
        thickness: 0.5,
        space: AppSpacing.lg,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.textOnCard,
          minimumSize: const Size.fromHeight(AppSpacing.minTapTarget),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.goldBright,
          side: const BorderSide(color: AppColors.goldDim),
          minimumSize: const Size.fromHeight(AppSpacing.minTapTarget),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.goldBright,
          textStyle: text.labelLarge,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.goldDim,
        textColor: AppColors.textPrimary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? AppColors.gold
              : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? AppColors.goldDim
              : AppColors.surfaceSunken,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.gold,
        inactiveTrackColor: AppColors.surfaceSunken,
        thumbColor: AppColors.goldBright,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: text.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
        ),
      ),
    );
  }

  /// Typography.
  ///
  /// The bundled Roboto is used rather than a downloaded font: the app must
  /// work with no network at all, and shipping a font file for milestone 1
  /// would be weight without benefit. Weight and letter spacing carry the
  /// premium feel instead.
  static TextTheme _textTheme() => const TextTheme(
        displaySmall: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w300,
          letterSpacing: 2.4,
          color: AppColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.8,
          color: AppColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        bodySmall: TextStyle(fontSize: 12, color: AppColors.textMuted),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
          color: AppColors.textMuted,
        ),
      );
}
