import 'package:flutter/material.dart';

import '../models/vehicle.dart';

/// UniTrack design system.
///
/// Material 3, prototype-inspired (v1.2.0): indigo primary, bold
/// readable type, generous spacing and expressive rounded cards.
/// Deliberately NOT a flat minimal grey look: the fleet status must
/// read at a glance from across the room, and the primary actions
/// must feel big and tappable.
///
/// The fleet summary strip is a gradient (indigo → blue → cyan) and
/// the bottom navigation uses an M3 active pill (indigo-100 in
/// light, indigo-800 in dark).
class AppColors {
  // Brand — Material 3 indigo, from the UI prototype.
  static const Color primary = Color(0xFF4F46E5); // indigo-600
  static const Color secondary = Color(0xFF00A896); // teal
  static const Color accent = Color(0xFFFFB020); // warm amber

  /// Indigo-100 — the active-pill background in the light theme.
  static const Color primaryContainerLight = Color(0xFFE0E7FF);

  /// Indigo-800 — the active-pill background in the dark theme.
  static const Color primaryContainerDark = Color(0xFF312E81);

  /// Gradient stops for the fleet summary strip
  /// (indigo → blue → cyan, as in the prototype).
  static const List<Color> summaryGradient = [
    Color(0xFF4F46E5),
    Color(0xFF2563EB),
    Color(0xFF06B6D4),
  ];

  // Fleet status — vivid and unmistakable.
  static const Color live = Color(0xFF00A651);
  static const Color idle = Color(0xFFF59E0B);
  static const Color unknown = Color(0xFF8A8FA3);
  static const Color expired = Color(0xFFE5484D);

  // Light theme surfaces — slate-50 background, white cards.
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightInk = Color(0xFF14142B);
  static const Color lightMuted = Color(0xFF5A5E73);
  static const Color lightFieldFill = Color(0xFFECEEF6);

  // Dark theme surfaces — deep navy #0B1120, not plain black.
  static const Color darkBackground = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF181C38);
  static const Color darkSurfaceRaised = Color(0xFF20264A);
  static const Color darkInk = Color(0xFFF2F3FA);
  static const Color darkMuted = Color(0xFFA7ABC2);

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

  /// A distinct bold colour per provider, used for badges and map pins.
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

/// The two UniTrack themes (light + dark). Everything screens build with
/// comes from here — no hard-coded colours or text styles in screens.
///
/// M3 indigo (v1.2.0): the same indigo-600 primary in both themes over
/// deep-navy dark surfaces, with an M3 active-pill navigation
/// indicator (indigo-100 light / indigo-800 dark) and slightly
/// stronger card outlines so cards read on small phones. Status
/// colours keep their meaning in both themes.
class AppTheme {
  static const double cardRadius = 20;
  static const double fieldRadius = 16;
  static const double buttonRadius = 16;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = AppColors.primary;
    final background = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final fieldFill = isDark
        ? AppColors.darkSurfaceRaised
        : AppColors.lightFieldFill;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      tertiary: AppColors.accent,
      error: AppColors.expired,
      onError: Colors.white,
      surface: surface,
      onSurface: ink,
      surfaceContainerLow: isDark
          ? AppColors.darkSurfaceRaised
          : const Color(0xFFE9EBF5),
      surfaceContainerHighest: isDark
          ? const Color(0xFF2A2F52)
          : const Color(0xFFE3E5F0),
      onSurfaceVariant: muted,
      outline: muted.withValues(alpha: 0.4),
      outlineVariant: muted.withValues(alpha: 0.2),
    );

    const displayStyle = TextStyle(
      fontSize: 44,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
      height: 1,
    );
    final textTheme = TextTheme(
      displayLarge: displayStyle.copyWith(color: ink),
      displayMedium: displayStyle.copyWith(fontSize: 34, color: ink),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: ink,
        letterSpacing: -0.5,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: ink, height: 1.4),
      bodyMedium: TextStyle(fontSize: 15, color: ink, height: 1.4),
      bodySmall: TextStyle(fontSize: 13, color: muted, height: 1.4),
      labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: muted,
      ),
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonRadius),
    );

    // Selected nav icon/label: indigo-600 on the light pill,
    // indigo-300 on the dark pill (indigo-600 on indigo-800 would
    // be unreadable).
    final selectedNavColor = isDark
        ? const Color(0xFFA5B4FC)
        : primary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: ink),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: isDark ? 0.10 : 0.06,
            ),
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: buttonShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
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
          borderSide: const BorderSide(color: AppColors.expired, width: 2),
        ),
        labelStyle: TextStyle(fontSize: 15, color: muted),
        hintStyle: TextStyle(fontSize: 15, color: muted),
        helperStyle: TextStyle(fontSize: 13, color: muted),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        // M3 active pill: solid indigo-100 / indigo-800, as in the
        // prototype — not a translucent wash.
        indicatorColor: isDark
            ? AppColors.primaryContainerDark
            : AppColors.primaryContainerLight,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? selectedNavColor
                : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: states.contains(WidgetState.selected)
                ? selectedNavColor
                : muted,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // NOTE: never use `ink` here — in the dark theme ink is near-white
        // (#F2F3FA), which made white snackbar text unreadable (white on
        // white). The background must stay dark in both themes.
        backgroundColor: isDark
            ? AppColors.darkSurfaceRaised
            : AppColors.lightInk,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: muted.withValues(alpha: 0.25),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: muted,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        subtitleTextStyle: TextStyle(fontSize: 14, color: muted),
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
