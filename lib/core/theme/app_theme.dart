import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: isLight ? AppColors.primary : AppColors.primaryLight,
      onPrimary: Colors.white,
      primaryContainer:
          isLight ? AppColors.primaryLight : AppColors.primaryDark,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.accent,
      onSecondary: const Color(0xFF04262A),
      error: AppColors.danger,
      onError: Colors.white,
      surface: isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
      onSurface: isLight ? AppColors.textLight : AppColors.textDark,
      surfaceContainerHighest:
          isLight ? AppColors.surfaceAltLight : AppColors.surfaceAltDark,
      outline: isLight ? AppColors.borderLight : AppColors.borderDark,
    );

    final base = ThemeData(
        useMaterial3: true, colorScheme: scheme, brightness: brightness);
    final muted = isLight ? AppColors.textMutedLight : AppColors.textMutedDark;

    return base.copyWith(
      scaffoldBackgroundColor: isLight ? AppColors.bgLight : AppColors.bgDark,
      textTheme: base.textTheme
          .copyWith(
            displaySmall: base.textTheme.displaySmall
                ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
            headlineSmall: base.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
            titleLarge: base.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
            titleMedium: base.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
            bodySmall:
                base.textTheme.bodySmall?.copyWith(color: muted, height: 1.4),
            labelLarge: base.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          )
          .apply(
            bodyColor: isLight ? AppColors.textLight : AppColors.textDark,
            displayColor: isLight ? AppColors.textLight : AppColors.textDark,
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? AppColors.bgLight : AppColors.bgDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: isLight ? AppColors.textLight : AppColors.textDark,
        ),
        iconTheme: IconThemeData(
            color: isLight ? AppColors.textLight : AppColors.textDark),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.md,
          side: BorderSide(
              color: scheme.outline.withValues(alpha: isLight ? 1 : 0.6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppColors.surfaceLight : AppColors.surfaceAltDark,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.lg),
        border: OutlineInputBorder(
            borderRadius: Radii.md,
            borderSide: BorderSide(color: scheme.outline)),
        enabledBorder: OutlineInputBorder(
            borderRadius: Radii.md,
            borderSide: BorderSide(color: scheme.outline)),
        focusedBorder: OutlineInputBorder(
            borderRadius: Radii.md,
            borderSide: BorderSide(color: scheme.primary, width: 1.6)),
        errorBorder: const OutlineInputBorder(
            borderRadius: Radii.md,
            borderSide: BorderSide(color: AppColors.danger)),
        focusedErrorBorder: const OutlineInputBorder(
            borderRadius: Radii.md,
            borderSide: BorderSide(color: AppColors.danger, width: 1.6)),
        hintStyle: TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(kMinTouchTarget),
          shape: const RoundedRectangleBorder(borderRadius: Radii.md),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(kMinTouchTarget),
          shape: const RoundedRectangleBorder(borderRadius: Radii.md),
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const RoundedRectangleBorder(borderRadius: Radii.pill),
        side: BorderSide(color: scheme.outline),
        backgroundColor: scheme.surface,
        selectedColor: scheme.primary,
        showCheckmark: false,
        // Keep chip text deterministic across Android versions. Leaving these
        // colours unresolved can make unselected labels inherit white in light
        // mode, which renders them invisible against the white chip surface.
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        secondaryLabelStyle: TextStyle(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isLight ? 0.12 : 0.28),
        indicatorShape: const RoundedRectangleBorder(borderRadius: Radii.pill),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isLight ? AppColors.textLight : AppColors.textDark),
        ),
      ),
      dividerTheme:
          DividerThemeData(color: scheme.outline, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lg),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: Radii.md),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
