import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Extra text styles the Material [TextTheme] has no slot for.
@immutable
class DevotionTextStyles extends ThemeExtension<DevotionTextStyles> {
  const DevotionTextStyles({
    required this.scriptureQuote,
    required this.overline,
    required this.timer,
  });

  /// Merriweather light italic used for scripture and pull quotes.
  final TextStyle scriptureQuote;

  /// Small all-caps gold label (e.g. "VERSE OF THE DAY").
  final TextStyle overline;

  /// Large tabular digits for the recording timer.
  final TextStyle timer;

  @override
  DevotionTextStyles copyWith({
    TextStyle? scriptureQuote,
    TextStyle? overline,
    TextStyle? timer,
  }) => DevotionTextStyles(
    scriptureQuote: scriptureQuote ?? this.scriptureQuote,
    overline: overline ?? this.overline,
    timer: timer ?? this.timer,
  );

  @override
  DevotionTextStyles lerp(DevotionTextStyles? other, double t) => this;
}

extension DevotionThemeX on BuildContext {
  DevotionTextStyles get devotionText =>
      Theme.of(this).extension<DevotionTextStyles>()!;
  TextTheme get text => Theme.of(this).textTheme;
}

abstract final class AppTheme {
  /// [useGoogleFonts] is disabled in tests, where runtime font fetching is
  /// unavailable.
  static ThemeData light({bool useGoogleFonts = true}) {
    TextStyle display(double size, FontWeight w, double height, double ls) {
      final base = TextStyle(
        fontSize: size,
        fontWeight: w,
        height: height / size,
        letterSpacing: ls * size,
        color: AppColors.ink,
      );
      return useGoogleFonts
          ? GoogleFonts.playfairDisplay(textStyle: base)
          : base;
    }

    TextStyle serif(
      double size,
      FontWeight w,
      double height, {
      FontStyle? style,
      Color color = AppColors.ink,
    }) {
      final base = TextStyle(
        fontSize: size,
        fontWeight: w,
        height: height / size,
        fontStyle: style,
        color: color,
      );
      return useGoogleFonts ? GoogleFonts.merriweather(textStyle: base) : base;
    }

    TextStyle sans(
      double size,
      FontWeight w,
      double height,
      double ls, {
      Color color = AppColors.ink,
    }) {
      final base = TextStyle(
        fontSize: size,
        fontWeight: w,
        height: height / size,
        letterSpacing: ls * size,
        color: color,
      );
      return useGoogleFonts
          ? GoogleFonts.plusJakartaSans(textStyle: base)
          : base;
    }

    final textTheme = TextTheme(
      displayLarge: display(40, FontWeight.w600, 52, -0.02),
      displayMedium: display(30, FontWeight.w600, 38, -0.01),
      displaySmall: display(26, FontWeight.w600, 34, -0.01),
      headlineLarge: display(26, FontWeight.w600, 34, -0.01),
      headlineMedium: display(22, FontWeight.w500, 30, 0),
      headlineSmall: display(19, FontWeight.w500, 26, 0),
      titleLarge: display(22, FontWeight.w600, 30, 0),
      titleMedium: sans(16, FontWeight.w600, 22, 0),
      titleSmall: sans(14, FontWeight.w600, 20, 0),
      bodyLarge: serif(16, FontWeight.w400, 28),
      bodyMedium: serif(14, FontWeight.w400, 24),
      bodySmall: sans(
        12,
        FontWeight.w400,
        16,
        0,
        color: AppColors.inkSecondary,
      ),
      labelLarge: sans(15, FontWeight.w600, 20, 0.01),
      labelMedium: sans(13, FontWeight.w600, 18, 0.02),
      labelSmall: sans(11, FontWeight.w700, 14, 0.04),
    );

    final scheme = const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryFixed,
      onPrimaryContainer: AppColors.primaryInk,
      secondary: AppColors.goldDeep,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.goldContainer,
      onSecondaryContainer: AppColors.onGoldContainer,
      tertiary: AppColors.teal,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorBg,
      surface: AppColors.canvas,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSecondary,
      surfaceContainerLowest: AppColors.card,
      surfaceContainerLow: AppColors.surfaceLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceHigh,
      outline: AppColors.inkMuted,
      outlineVariant: AppColors.linen,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: AppRadii.control,
      borderSide: const BorderSide(color: AppColors.linen),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: textTheme,
      extensions: [
        DevotionTextStyles(
          scriptureQuote: serif(
            19,
            FontWeight.w300,
            34,
            style: FontStyle.italic,
          ),
          overline: sans(
            11,
            FontWeight.w700,
            14,
            0.08,
            color: AppColors.goldDeep,
          ),
          timer: sans(
            56,
            FontWeight.w700,
            64,
            0,
            color: AppColors.primaryInk,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.primaryInk,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium?.copyWith(
          color: AppColors.primaryInk,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(color: AppColors.linen),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.surfaceHigh,
          minimumSize: const Size(AppSpacing.minTap, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.control),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.recessed,
          minimumSize: const Size(AppSpacing.minTap, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: const BorderSide(color: AppColors.gold, width: 1.5),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.control),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(AppSpacing.minTap, AppSpacing.minTap),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.primaryInk,
          minimumSize: const Size(AppSpacing.minTap, AppSpacing.minTap),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: textTheme.labelLarge?.copyWith(
          color: AppColors.inkMuted,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: AppColors.inkSecondary,
          fontWeight: FontWeight.w500,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: AppColors.primary,
        side: const BorderSide(color: AppColors.linen),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelSmall,
        secondaryLabelStyle: textTheme.labelSmall?.copyWith(
          color: AppColors.onPrimary,
        ),
        checkmarkColor: AppColors.goldContainer,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.canvas.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryInk
                : AppColors.inkMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryInk
                : AppColors.inkMuted,
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.goldDeep,
        inactiveTrackColor: AppColors.linen,
        thumbColor: AppColors.gold,
        trackHeight: 4,
        overlayColor: Color(0x33C5A059),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.linen,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.linen, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDeep,
        contentTextStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.onPrimary,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.control),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.card),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
      ),
    );
  }
}
