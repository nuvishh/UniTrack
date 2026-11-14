import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/theme_seed.dart';
import '../models/vehicle.dart';

/// UniTrack design system.
///
/// Material You (v1.3.0): five switchable M3 seed palettes (Royal
/// Violet default since v1.4.0, Ocean Slate, Sage Emerald, Indigo Dusk,
/// Terracotta — see [ThemeSeed]), with Poppins for UI text and
/// JetBrains Mono for reg numbers / mono labels. No gradients anywhere — surfaces
/// are tonal (primaryContainer / secondaryContainer / surface
/// containers) and status reads through the emerald / amber / slate
/// status colours.
///
/// The fleet summary is a tonal primary-container card with stat
/// tiles in surfaceContainerLowest (light) / surfaceContainerLow
/// (dark). The bottom navigation is an 80px M3 bar with a
/// secondaryContainer active pill.
///
/// NOTE on google_fonts 9: `GoogleFonts.poppinsTextTheme`
/// takes the `material_ui` fork's TextTheme, not Flutter's, so the
/// font is applied per TextStyle instead (see [_poppins]).
class AppColors {
  // Fleet status — prototype: Live emerald-500, Idle amber-500,
  // Offline slate-400 (not rose). Both "offline" states (unknown
  // and expired) share the slate.
  static const Color live = Color(0xFF10B981);
  static const Color idle = Color(0xFFF59E0B);
  static const Color unknown = Color(0xFF94A3B8);
  static const Color expired = Color(0xFF94A3B8);

  /// Errors / failures — the old rose, kept for error UI only (it is
  /// NOT a status colour any more).
  static const Color error = Color(0xFFE5484D);

  /// Status-badge text: darker in light mode, lighter in dark mode
  /// (prototype statusBadgeHTML: emerald-700 / emerald-300,
  /// amber-800 / amber-300).
  static const Color liveTextLight = Color(0xFF047857);
  static const Color liveTextDark = Color(0xFF6EE7B7);
  static const Color idleTextLight = Color(0xFF92400E);
  static const Color idleTextDark = Color(0xFFFCD34D);

  /// Colour for a fleet [VehicleStatus].
  static Color statusColor(VehicleStatus status) {
    switch (status) {
      case VehicleStatus.live:
        return live;
      case VehicleStatus.idle:
        return idle;
      case VehicleStatus.unknown:
        return unknown;
      case VehicleStatus.expired:
        return expired;
    }
  }

  /// A distinct bold colour per provider, used for icon tiles (not
  /// for the theme — provider badges are secondaryContainer pills).
  static Color providerColor(String providerKey) {
    switch (providerKey) {
      case 'transight':
        return const Color(0xFF00A896);
      case 'aargee':
        return const Color(0xFF2547F4);
      case 'radiant':
        return const Color(0xFFF97316);
      case 'mercydatrack':
        return const Color(0xFF7C3AED);
      case 'mercydatrack4g':
        return const Color(0xFF0E7490);
      case 'pauldeatrack':
        return const Color(0xFFDB2777);
      case 'voltysoft':
        return const Color(0xFF059669);
      case 'hashtrace':
        return const Color(0xFF0891B2);
      default:
        return unknown;
    }
  }
}

/// The two UniTrack themes (light + dark) for a [ThemeSeed].
/// Everything screens build with comes from here — no hard-coded
/// colours or text styles in screens.
///
/// Material You, seed-parameterised: tonal surfaces, secondaryContainer
/// active-pill navigation, pill buttons, and Poppins
/// throughout (JetBrains Mono for reg numbers via [mono]).
class AppTheme {
  static const double cardRadius = 24;
  static const double fieldRadius = 16;

  /// The default (Royal Violet) themes.
  static ThemeData get light => lightFor(ThemeSeed.royal);
  static ThemeData get dark => darkFor(ThemeSeed.royal);

  static ThemeData lightFor(ThemeSeed seed) => _build(Brightness.light, seed);
  static ThemeData darkFor(ThemeSeed seed) => _build(Brightness.dark, seed);

  /// JetBrains Mono — reg numbers, IMEIs, coordinates and other mono
  /// labels. Pass the size/weight the spot needs.
  static TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
  );

  /// Applies Poppins to one text style. (google_fonts 9's
  /// `*TextTheme` helpers take the `material_ui` fork's TextTheme,
  /// not Flutter's, so the font is applied style by style.)
  static TextStyle _poppins(TextStyle style) =>
      GoogleFonts.poppins(textStyle: style);

  static ThemeData _build(Brightness brightness, ThemeSeed seed) {
    final isDark = brightness == Brightness.dark;
    final palette = isDark ? seed.dark : seed.light;
    final primary = palette.primary;
    final onPrimary = palette.onPrimary;
    final primaryContainer = palette.primaryContainer;
    final onPrimaryContainer = palette.onPrimaryContainer;
    final secondaryContainer = palette.secondaryContainer;
    final onSecondaryContainer = palette.onSecondaryContainer;
    final tertiaryContainer = palette.tertiaryContainer;
    final onTertiaryContainer = palette.onTertiaryContainer;
    final surface = palette.surface;
    final surfaceLowest = palette.surfaceLowest;
    final surfaceLow = palette.surfaceLow;
    final surfaceContainer = palette.surfaceContainer;
    final surfaceHigh = palette.surfaceHigh;
    final surfaceHighest = palette.surfaceHighest;
    final onSurface = palette.onSurface;
    final onSurfaceVariant = palette.onSurfaceVariant;
    final outline = palette.outline;
    final outlineVariant = palette.outlineVariant;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: primary,
      onSecondary: onPrimary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: primaryContainer,
      onTertiary: onPrimaryContainer,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: AppColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: surfaceLowest,
      surfaceContainerLow: surfaceLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHighest,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      // M3 inverse surface: the snackbar background. Light theme =
      // dark surface, dark theme = light surface (the prototype's
      // toast is onSurface bg + surface text).
      inverseSurface: onSurface,
      onInverseSurface: surface,
    );

    final displayStyle = _poppins(
      TextStyle(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        height: 1,
        color: onSurface,
      ),
    );
    final textTheme = TextTheme(
      displayLarge: displayStyle,
      displayMedium: _poppins(displayStyle.copyWith(fontSize: 34)),
      headlineMedium: _poppins(
        TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: onSurface,
          letterSpacing: -0.5,
        ),
      ),
      headlineSmall: _poppins(
        TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: onSurface),
      ),
      titleLarge: _poppins(
        TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: onSurface),
      ),
      titleMedium: _poppins(
        TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: onSurface),
      ),
      titleSmall: _poppins(
        TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: onSurface),
      ),
      bodyLarge: _poppins(
        TextStyle(fontSize: 16, color: onSurface, height: 1.4),
      ),
      bodyMedium: _poppins(
        TextStyle(fontSize: 15, color: onSurface, height: 1.4),
      ),
      bodySmall: _poppins(
        TextStyle(fontSize: 13, color: onSurfaceVariant, height: 1.4),
      ),
      labelLarge: _poppins(
        TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: onSurface),
      ),
      labelMedium: _poppins(
        TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: onSurfaceVariant,
        ),
      ),
    );

    // Pill buttons — every primary / secondary action is rounded-full.
    const buttonShape = StadiumBorder();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: onSurface,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        color: surfaceLow,
        // RingWise look (v1.4.0): soft purple-tinted shadow under
        // white cards on the lavender surface.
        elevation: 2,
        shadowColor: const Color(0x146C4CF1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: buttonShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: TextStyle(fontSize: 15, color: onSurfaceVariant),
        hintStyle: TextStyle(fontSize: 15, color: onSurfaceVariant),
        helperStyle: TextStyle(fontSize: 13, color: onSurfaceVariant),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selectedColor: secondaryContainer,
        checkmarkColor: onSecondaryContainer,
        labelStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        side: BorderSide(color: outlineVariant),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceContainer,
        elevation: 0,
        shadowColor: Colors.transparent,
        // M3 active pill: secondaryContainer, 64x32, as in the
        // prototype — not a translucent wash.
        indicatorColor: secondaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? onSecondaryContainer
                : onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? onSurface
                : onSurfaceVariant,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // M3 inverse surface: dark bg + light text in light mode,
        // light bg + dark text in dark mode. Never hard-code a dark
        // background — in dark mode the inverse surface is light, and
        // white text on it was the v1.1.1 unreadable-toast bug.
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: colorScheme.onInverseSurface,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: onSurfaceVariant.withValues(alpha: 0.25),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: onSurfaceVariant,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        subtitleTextStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: onSurfaceVariant,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : null,
        ),
      ),
    );
  }
}
