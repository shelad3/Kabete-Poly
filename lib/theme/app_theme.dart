// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design tokens for the Kabete Poly ecosystem.
class AppColors {
  static const Color primary = Color(0xFF1A237E);
  static const Color accent = Color(0xFFFF8F00);
  static const Color backgroundLight = Color(0xFFF6F7FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceTint = Color(0xFFE8EAF6);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
  static const Color info = Color(0xFF1565C0);
  static const Color textPrimary = Color(0xFF1B1F3B);
  static const Color textSecondary = Color(0xFF5C617A);
  static const Color outline = Color(0xFFE2E4EE);
  static const Color divider = Color(0xFFECEEF4);
  static const Color scrim = Color(0x1A1A237E);

  static const Color surfaceDark = Color(0xFF12121F);
  static const Color surfaceDarkCard = Color(0xFF1E1E33);
  static const Color surfaceDarkElevated = Color(0xFF2A2A44);
  static const Color textDarkPrimary = Color(0xFFF4F4FB);
  static const Color textDarkSecondary = Color(0xFFB9BCCE);
  static const Color outlineDark = Color(0xFF2E2E48);
}

/// Spacing scale used across every screen.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double page = 20;
}

/// Corner radius scale.
class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 100;
}

/// Shared component themes for all three app modes.
abstract class _BaseTheme {
  static TextTheme _textTheme(Color textColor, Color subtleColor) {
    final base = GoogleFonts.outfitTextTheme();
    return base.copyWith(
      displaySmall: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleSmall: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      bodyLarge: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      bodyMedium: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      bodySmall: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: subtleColor,
      ),
      labelLarge: GoogleFonts.outfit(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelMedium: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  static AppBarTheme _appBarTheme(Color color) => AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        iconTheme: IconThemeData(color: color),
      );

  static CardThemeData _cardTheme(Color surface) => CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.scrim,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      );

  static ElevatedButtonThemeData _elevatedButtonTheme(Color primary) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static OutlinedButtonThemeData _outlinedButtonTheme(
    Color primary,
    Color outline,
  ) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: BorderSide(color: outline, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static TextButtonThemeData _textButtonTheme(Color primary) =>
      TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static InputDecorationTheme _inputTheme(
    Color fill,
    Color primary,
    Color label,
    Color outline,
  ) =>
      InputDecorationTheme(
        filled: true,
        fillColor: fill,
        hintStyle: GoogleFonts.outfit(color: label),
        labelStyle: GoogleFonts.outfit(color: label, fontWeight: FontWeight.w500),
        prefixIconColor: label,
        suffixIconColor: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
      );

  static ChipThemeData _chipTheme(Color primary, Color surface) => ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary.withValues(alpha: 0.12),
        labelStyle: GoogleFonts.outfit(fontSize: 13, color: primary),
        secondaryLabelStyle: GoogleFonts.outfit(fontSize: 13, color: primary),
        side: BorderSide(color: primary.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      );

  static SnackBarThemeData _snackBarTheme(Color background) => SnackBarThemeData(
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        contentTextStyle: GoogleFonts.outfit(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: Colors.white,
      );

  static DialogThemeData _dialogTheme(Color surface, Color primary) =>
      DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        contentTextStyle: GoogleFonts.outfit(fontSize: 14),
      );

  static NavigationBarThemeData _navigationBarTheme(
    Color surface,
    Color primary,
  ) =>
      NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: primary.withValues(alpha: 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(size: 24, color: primary),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      );
}

class AppTheme {
  static const Color primaryColor = AppColors.primary;
  static const Color accentColor = AppColors.accent;

  static const Color backgroundColor = AppColors.backgroundLight;
  static const Color cardColor = AppColors.surfaceLight;
  static const Color errorColor = AppColors.error;
  static const Color successColor = AppColors.success;

  /// KNP flagship theme — the default look of the app.
  static ThemeData get knpTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.backgroundLight,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      textTheme: _BaseTheme._textTheme(
        AppColors.textPrimary,
        AppColors.textSecondary,
      ),
      appBarTheme: _BaseTheme._appBarTheme(AppColors.primary),
      cardTheme: _BaseTheme._cardTheme(AppColors.surfaceLight),
      elevatedButtonTheme: _BaseTheme._elevatedButtonTheme(AppColors.primary),
      outlinedButtonTheme: _BaseTheme._outlinedButtonTheme(
        AppColors.primary,
        AppColors.outline,
      ),
      textButtonTheme: _BaseTheme._textButtonTheme(AppColors.primary),
      inputDecorationTheme: _BaseTheme._inputTheme(
        AppColors.surfaceLight,
        AppColors.primary,
        AppColors.textSecondary,
        AppColors.outline,
      ),
      chipTheme: _BaseTheme._chipTheme(AppColors.primary, AppColors.surfaceTint),
      snackBarTheme: _BaseTheme._snackBarTheme(AppColors.primary),
      dialogTheme: _BaseTheme._dialogTheme(
        AppColors.surfaceLight,
        AppColors.primary,
      ),
      navigationBarTheme: _BaseTheme._navigationBarTheme(
        AppColors.surfaceLight,
        AppColors.primary,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dividerColor: AppColors.divider,
      dividerTheme: DividerThemeData(
        color: AppColors.divider,
        space: 1,
        thickness: 1,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(AppRadius.xl)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceTint,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.primary,
        textColor: AppColors.textPrimary,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        labelStyle: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.outline,
        ),
      ),
    );
  }

  /// Light mode — same system, tinted surfaces.
  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.info,
      secondary: AppColors.accent,
      surface: AppColors.backgroundLight,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      textTheme: _BaseTheme._textTheme(
        AppColors.textPrimary,
        AppColors.textSecondary,
      ),
      appBarTheme: _BaseTheme._appBarTheme(AppColors.info),
      cardTheme: _BaseTheme._cardTheme(AppColors.surfaceLight),
      elevatedButtonTheme: _BaseTheme._elevatedButtonTheme(AppColors.info),
      outlinedButtonTheme: _BaseTheme._outlinedButtonTheme(
        AppColors.info,
        AppColors.outline,
      ),
      textButtonTheme: _BaseTheme._textButtonTheme(AppColors.info),
      inputDecorationTheme: _BaseTheme._inputTheme(
        AppColors.surfaceLight,
        AppColors.info,
        AppColors.textSecondary,
        AppColors.outline,
      ),
      chipTheme: _BaseTheme._chipTheme(AppColors.info, AppColors.surfaceTint),
      snackBarTheme: _BaseTheme._snackBarTheme(AppColors.info),
      dialogTheme: _BaseTheme._dialogTheme(AppColors.surfaceLight, AppColors.info),
      navigationBarTheme: _BaseTheme._navigationBarTheme(
        AppColors.surfaceLight,
        AppColors.info,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dividerColor: AppColors.divider,
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.info,
        linearTrackColor: AppColors.surfaceTint,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.info,
        textColor: AppColors.textPrimary,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.info
              : AppColors.outline,
        ),
      ),
    );
  }

  /// Dark mode — same system, deep surfaces.
  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: const Color(0xFF9FA8DA),
      secondary: const Color(0xFFFFD54F),
      surface: AppColors.surfaceDark,
      error: const Color(0xFFEF5350),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surfaceDark,
      textTheme: _BaseTheme._textTheme(
        AppColors.textDarkPrimary,
        AppColors.textDarkSecondary,
      ),
      appBarTheme: _BaseTheme._appBarTheme(AppColors.textDarkPrimary),
      cardTheme: _BaseTheme._cardTheme(AppColors.surfaceDarkCard),
      elevatedButtonTheme: _BaseTheme._elevatedButtonTheme(
        const Color(0xFF7986CB),
      ),
      outlinedButtonTheme: _BaseTheme._outlinedButtonTheme(
        AppColors.textDarkPrimary,
        AppColors.outlineDark,
      ),
      textButtonTheme: _BaseTheme._textButtonTheme(AppColors.textDarkPrimary),
      inputDecorationTheme: _BaseTheme._inputTheme(
        AppColors.surfaceDarkCard,
        const Color(0xFF9FA8DA),
        AppColors.textDarkSecondary,
        AppColors.outlineDark,
      ),
      chipTheme: _BaseTheme._chipTheme(
        AppColors.textDarkPrimary,
        AppColors.surfaceDarkElevated,
      ),
      snackBarTheme: _BaseTheme._snackBarTheme(AppColors.surfaceDarkElevated),
      dialogTheme: _BaseTheme._dialogTheme(
        AppColors.surfaceDarkCard,
        AppColors.textDarkPrimary,
      ),
      navigationBarTheme: _BaseTheme._navigationBarTheme(
        AppColors.surfaceDarkCard,
        AppColors.textDarkPrimary,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDarkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dividerColor: AppColors.outlineDark,
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surfaceDarkCard,
        surfaceTintColor: Colors.transparent,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF9FA8DA),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFFFD54F),
        foregroundColor: Colors.black87,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFF9FA8DA),
        textColor: AppColors.textDarkPrimary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.black87
              : AppColors.textDarkSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xFF9FA8DA)
              : AppColors.outlineDark,
        ),
      ),
    );
  }
}
