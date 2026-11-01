import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// نظام التصميم الموحّد للتطبيق.
///
/// يعتمد على لوحة [AppColors] وخط Tajawal، ويضبط كل مكوّنات Material 3
/// حتى تبدو الشاشات متناسقة دون تكرار الأنماط في كل صفحة.
/// يمكن تخصيص الألوان والخطوط عبر تعديل AppColors و AppTypography.
class AppTheme {
  const AppTheme._();

  static const Color seed = AppColors.forest;
  static const Color accent = AppColors.gold;

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark ? _darkScheme : _lightScheme;
    final textTheme = AppTypography.textTheme(
      primaryText: scheme.onSurface,
      secondaryText: scheme.onSurfaceVariant,
    );

    final radius = BorderRadius.circular(16);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: AppTypography.family,
      textTheme: textTheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.nightCanvas : AppColors.canvas,
      canvasColor: isDark ? AppColors.nightCanvas : AppColors.canvas,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    return base.copyWith(
      primaryColor: scheme.primary,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? AppColors.nightCanvas : AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
        actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? AppColors.nightCard : AppColors.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.deepForest.withValues(alpha: 0.16),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? AppColors.nightLine : AppColors.line,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark ? AppColors.nightSurface : scheme.surfaceContainerLowest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.mist),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.primary,
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        focusElevation: 4,
        hoverElevation: 4,
        highlightElevation: 2,
        extendedTextStyle: const TextStyle(
          fontFamily: AppTypography.family,
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.nightSurface : AppColors.card,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerHigh,
        side: BorderSide(
          color: isDark ? AppColors.nightLine : AppColors.line,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
        checkmarkColor: scheme.onPrimaryContainer,
        showCheckmark: false,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.nightLine : AppColors.line,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.nightCard : AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.nightCard : AppColors.card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: isDark ? AppColors.nightCard : AppColors.card,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.nightSurface : AppColors.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.12),
        circularTrackColor: scheme.primary.withValues(alpha: 0.12),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.nightSurface : AppColors.ink,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.22),
        selectionHandleColor: scheme.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
      ),
    );
  }

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.forest,
    onPrimary: Colors.white,
    primaryContainer: AppColors.mintSoft,
    onPrimaryContainer: AppColors.deepForest,
    secondary: AppColors.goldDeep,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.goldWash,
    onSecondaryContainer: Color(0xFF5E3B06),
    tertiary: AppColors.info,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFDCE9F8),
    onTertiaryContainer: Color(0xFF0B3560),
    error: AppColors.danger,
    onError: Colors.white,
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: AppColors.card,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.slate,
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFAFBF8),
    surfaceContainer: Color(0xFFF2F5F1),
    surfaceContainerHigh: Color(0xFFEBF0EA),
    surfaceContainerHighest: Color(0xFFE4EAE3),
    outline: Color(0xFFA9B6AE),
    outlineVariant: AppColors.line,
    shadow: Color(0x33000000),
    scrim: Color(0x80000000),
    inverseSurface: Color(0xFF1B2A23),
    onInverseSurface: Color(0xFFEAF2EC),
    inversePrimary: AppColors.mint,
    surfaceTint: Colors.transparent,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF5FD6AC),
    onPrimary: Color(0xFF04241A),
    primaryContainer: Color(0xFF10402F),
    onPrimaryContainer: Color(0xFFB9F0DA),
    secondary: Color(0xFFF0C16A),
    onSecondary: Color(0xFF3E2A05),
    secondaryContainer: Color(0xFF553C10),
    onSecondaryContainer: Color(0xFFFBE0AC),
    tertiary: Color(0xFF8FC2F5),
    onTertiary: Color(0xFF062844),
    tertiaryContainer: Color(0xFF103B5C),
    onTertiaryContainer: Color(0xFFCDE4FB),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: AppColors.nightSurface,
    onSurface: AppColors.nightInk,
    onSurfaceVariant: AppColors.nightMuted,
    surfaceContainerLowest: Color(0xFF07100C),
    surfaceContainerLow: AppColors.nightSurface,
    surfaceContainer: Color(0xFF16231D),
    surfaceContainerHigh: Color(0xFF1C2B24),
    surfaceContainerHighest: Color(0xFF23342C),
    outline: Color(0xFF86968D),
    outlineVariant: AppColors.nightLine,
    shadow: Color(0xFF000000),
    scrim: Color(0xCC000000),
    inverseSurface: Color(0xFFE8F1EB),
    onInverseSurface: Color(0xFF12201A),
    inversePrimary: AppColors.forest,
    surfaceTint: Colors.transparent,
  );
}

/// اختصارات ألوان تراعي الوضع الليلي.
extension GenericThemeX on BuildContext {
  bool get isNight => Theme.of(this).brightness == Brightness.dark;

  Color get surfaceCard => isNight ? AppColors.nightCard : AppColors.card;

  Color get surfaceSoft =>
      isNight ? AppColors.nightSurface : const Color(0xFFF0F4EF);

  Color get hairline => isNight ? AppColors.nightLine : AppColors.line;

  Color get inkColor => isNight ? AppColors.nightInk : AppColors.ink;

  Color get mutedColor => isNight ? AppColors.nightMuted : AppColors.slate;

  Color get canvasColor => isNight ? AppColors.nightCanvas : AppColors.canvas;
}
