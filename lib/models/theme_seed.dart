import 'package:flutter/material.dart';

/// One M3 tonal palette: the full light + dark colour set for a seed.
///
/// Values are verbatim from the UI prototype's `M3_PALETTES` const —
/// each seed has its own surfaces, never ocean's reused.
class SeedPalette {
  const SeedPalette({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.surface,
    required this.surfaceLowest,
    required this.surfaceLow,
    required this.surfaceContainer,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color surface;
  final Color surfaceLowest;
  final Color surfaceLow;
  final Color surfaceContainer;
  final Color surfaceHigh;
  final Color surfaceHighest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
}

/// A Material You colour seed: id, display name, swatch colour and the
/// full light + dark palettes.
///
/// The prototype ships five: royal (default since v1.4.0), ocean, sage,
/// indigo, terracotta. A new seed is data only — add its palettes here
/// and it appears in the Settings picker with no other code changes.
class ThemeSeed {
  const ThemeSeed({
    required this.id,
    required this.name,
    required this.swatch,
    required this.light,
    required this.dark,
  });

  final String id;
  final String name;

  /// The seed's swatch colour, shown as the dot in the picker.
  final Color swatch;

  final SeedPalette light;
  final SeedPalette dark;

  static const List<ThemeSeed> values = [
    royal,
    ocean,
    sage,
    indigo,
    terracotta,
  ];

  /// The default seed since v1.4.0 (RingWise look): lavender surfaces,
  /// purple primary, Poppins.
  static const ThemeSeed royal = ThemeSeed(
    id: 'royal',
    name: 'Royal Violet',
    swatch: Color(0xFF6C4CF1),
    light: SeedPalette(
      primary: Color(0xFF6C4CF1),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE4DEFF),
      onPrimaryContainer: Color(0xFF1E1B4B),
      secondaryContainer: Color(0xFFEDE9FE),
      onSecondaryContainer: Color(0xFF2E1065),
      tertiaryContainer: Color(0xFFD1FAE5),
      onTertiaryContainer: Color(0xFF022C22),
      surface: Color(0xFFF5F3FF),
      surfaceLowest: Color(0xFFFFFFFF),
      surfaceLow: Color(0xFFEFEAFF),
      surfaceContainer: Color(0xFFE9E4FF),
      surfaceHigh: Color(0xFFE0D9FB),
      surfaceHighest: Color(0xFFD6CCF5),
      onSurface: Color(0xFF17142B),
      onSurfaceVariant: Color(0xFF5B5570),
      outline: Color(0xFF7A7390),
      outlineVariant: Color(0xFFD8D2EC),
    ),
    dark: SeedPalette(
      primary: Color(0xFFB7A6FF),
      onPrimary: Color(0xFF2E1065),
      primaryContainer: Color(0xFF4C1D95),
      onPrimaryContainer: Color(0xFFEDE9FE),
      secondaryContainer: Color(0xFF3B3355),
      onSecondaryContainer: Color(0xFFEDE9FE),
      tertiaryContainer: Color(0xFF14532D),
      onTertiaryContainer: Color(0xFFD1FAE5),
      surface: Color(0xFF14101F),
      surfaceLowest: Color(0xFF0D0A16),
      surfaceLow: Color(0xFF1B1729),
      surfaceContainer: Color(0xFF231E33),
      surfaceHigh: Color(0xFF2D2740),
      surfaceHighest: Color(0xFF383050),
      onSurface: Color(0xFFEAE6F9),
      onSurfaceVariant: Color(0xFFA49DC0),
      outline: Color(0xFF7C7494),
      outlineVariant: Color(0xFF37304D),
    ),
  );

  /// Ocean Slate — the default seed from v1.3.0 until v1.3.1: deep teal,
  /// slate surfaces.
  static const ThemeSeed ocean = ThemeSeed(
    id: 'ocean',
    name: 'Ocean Slate',
    swatch: Color(0xFF0F4C5C),
    light: SeedPalette(
      primary: Color(0xFF0F4C5C),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFB6EAFF),
      onPrimaryContainer: Color(0xFF001F28),
      secondaryContainer: Color(0xFFCFE6F1),
      onSecondaryContainer: Color(0xFF071E26),
      tertiaryContainer: Color(0xFFE1E0FF),
      onTertiaryContainer: Color(0xFF171937),
      surface: Color(0xFFF8FAFC),
      surfaceLowest: Color(0xFFFFFFFF),
      surfaceLow: Color(0xFFF1F5F9),
      surfaceContainer: Color(0xFFE2E8F0),
      surfaceHigh: Color(0xFFDCE4EC),
      surfaceHighest: Color(0xFFD2DCE6),
      onSurface: Color(0xFF0F172A),
      onSurfaceVariant: Color(0xFF475569),
      outline: Color(0xFF64748B),
      outlineVariant: Color(0xFFCBD5E1),
    ),
    dark: SeedPalette(
      primary: Color(0xFF7AD5F5),
      onPrimary: Color(0xFF003543),
      primaryContainer: Color(0xFF004E60),
      onPrimaryContainer: Color(0xFFB6EAFF),
      secondaryContainer: Color(0xFF2B424B),
      onSecondaryContainer: Color(0xFFCFE6F1),
      tertiaryContainer: Color(0xFF3E4161),
      onTertiaryContainer: Color(0xFFE1E0FF),
      surface: Color(0xFF0D1417),
      surfaceLowest: Color(0xFF080D0F),
      surfaceLow: Color(0xFF161E22),
      surfaceContainer: Color(0xFF1D272C),
      surfaceHigh: Color(0xFF263238),
      surfaceHighest: Color(0xFF303E45),
      onSurface: Color(0xFFE2E8F0),
      onSurfaceVariant: Color(0xFF94A3B8),
      outline: Color(0xFF788896),
      outlineVariant: Color(0xFF2E3B42),
    ),
  );

  static const ThemeSeed sage = ThemeSeed(
    id: 'sage',
    name: 'Sage Emerald',
    swatch: Color(0xFF1B6B52),
    light: SeedPalette(
      primary: Color(0xFF1B6B52),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFA6F2D1),
      onPrimaryContainer: Color(0xFF002116),
      secondaryContainer: Color(0xFFCEE9DC),
      onSecondaryContainer: Color(0xFF092017),
      tertiaryContainer: Color(0xFFC5E7FF),
      onTertiaryContainer: Color(0xFF001E2E),
      surface: Color(0xFFF6FAF7),
      surfaceLowest: Color(0xFFFFFFFF),
      surfaceLow: Color(0xFFEEF5F0),
      surfaceContainer: Color(0xFFE2ECE6),
      surfaceHigh: Color(0xFFD8E4DD),
      surfaceHighest: Color(0xFFCEDCD4),
      onSurface: Color(0xFF0F1A15),
      onSurfaceVariant: Color(0xFF42524A),
      outline: Color(0xFF67786F),
      outlineVariant: Color(0xFFC5D3CB),
    ),
    dark: SeedPalette(
      primary: Color(0xFF82D9B8),
      onPrimary: Color(0xFF003828),
      primaryContainer: Color(0xFF00513C),
      onPrimaryContainer: Color(0xFFA6F2D1),
      secondaryContainer: Color(0xFF2E473C),
      onSecondaryContainer: Color(0xFFCEE9DC),
      tertiaryContainer: Color(0xFF22495E),
      onTertiaryContainer: Color(0xFFC5E7FF),
      surface: Color(0xFF0E1512),
      surfaceLowest: Color(0xFF090E0C),
      surfaceLow: Color(0xFF16201B),
      surfaceContainer: Color(0xFF1D2923),
      surfaceHigh: Color(0xFF26342D),
      surfaceHighest: Color(0xFF304038),
      onSurface: Color(0xFFE0ECE5),
      onSurfaceVariant: Color(0xFF98ABA1),
      outline: Color(0xFF768A80),
      outlineVariant: Color(0xFF2E3E36),
    ),
  );

  static const ThemeSeed indigo = ThemeSeed(
    id: 'indigo',
    name: 'Indigo Dusk',
    swatch: Color(0xFF3F51B5),
    light: SeedPalette(
      primary: Color(0xFF3F51B5),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFDDE1FF),
      onPrimaryContainer: Color(0xFF001258),
      secondaryContainer: Color(0xFFDEE1F9),
      onSecondaryContainer: Color(0xFF161B2C),
      tertiaryContainer: Color(0xFFFCD7FB),
      onTertiaryContainer: Color(0xFF29132D),
      surface: Color(0xFFF9F8FF),
      surfaceLowest: Color(0xFFFFFFFF),
      surfaceLow: Color(0xFFF1F1FA),
      surfaceContainer: Color(0xFFE6E7F2),
      surfaceHigh: Color(0xFFDCDEEB),
      surfaceHighest: Color(0xFFD2D4E3),
      onSurface: Color(0xFF131624),
      onSurfaceVariant: Color(0xFF46495C),
      outline: Color(0xFF6E7185),
      outlineVariant: Color(0xFFC8CADB),
    ),
    dark: SeedPalette(
      primary: Color(0xFFBAC3FF),
      onPrimary: Color(0xFF0A2185),
      primaryContainer: Color(0xFF25399B),
      onPrimaryContainer: Color(0xFFDDE1FF),
      secondaryContainer: Color(0xFF3A3F54),
      onSecondaryContainer: Color(0xFFDEE1F9),
      tertiaryContainer: Color(0xFF563C58),
      onTertiaryContainer: Color(0xFFFCD7FB),
      surface: Color(0xFF11131A),
      surfaceLowest: Color(0xFF0B0D13),
      surfaceLow: Color(0xFF191C26),
      surfaceContainer: Color(0xFF202430),
      surfaceHigh: Color(0xFF2A2F3D),
      surfaceHighest: Color(0xFF343A4A),
      onSurface: Color(0xFFE3E5F2),
      onSurfaceVariant: Color(0xFF9EA3B8),
      outline: Color(0xFF7B8096),
      outlineVariant: Color(0xFF323747),
    ),
  );

  static const ThemeSeed terracotta = ThemeSeed(
    id: 'terracotta',
    name: 'Terracotta',
    swatch: Color(0xFF9C4129),
    light: SeedPalette(
      primary: Color(0xFF9C4129),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFFFDBD1),
      onPrimaryContainer: Color(0xFF3B0900),
      secondaryContainer: Color(0xFFF5DED7),
      onSecondaryContainer: Color(0xFF2C150F),
      tertiaryContainer: Color(0xFFF4E1A6),
      onTertiaryContainer: Color(0xFF241A00),
      surface: Color(0xFFFFF8F6),
      surfaceLowest: Color(0xFFFFFFFF),
      surfaceLow: Color(0xFFF9F0ED),
      surfaceContainer: Color(0xFFF1E5E1),
      surfaceHigh: Color(0xFFE8DBD6),
      surfaceHighest: Color(0xFFDFD1CC),
      onSurface: Color(0xFF201614),
      onSurfaceVariant: Color(0xFF53433F),
      outline: Color(0xFF7C6A65),
      outlineVariant: Color(0xFFD6C4BE),
    ),
    dark: SeedPalette(
      primary: Color(0xFFFFB5A0),
      onPrimary: Color(0xFF5E1603),
      primaryContainer: Color(0xFF7D2B15),
      onPrimaryContainer: Color(0xFFFFDBD1),
      secondaryContainer: Color(0xFF573D36),
      onSecondaryContainer: Color(0xFFF5DED7),
      tertiaryContainer: Color(0xFF534619),
      onTertiaryContainer: Color(0xFFF4E1A6),
      surface: Color(0xFF181210),
      surfaceLowest: Color(0xFF110C0B),
      surfaceLow: Color(0xFF221A18),
      surfaceContainer: Color(0xFF2A211E),
      surfaceHigh: Color(0xFF352B28),
      surfaceHighest: Color(0xFF403531),
      onSurface: Color(0xFFEFE0DC),
      onSurfaceVariant: Color(0xFFB5A19B),
      outline: Color(0xFF8F7B75),
      outlineVariant: Color(0xFF423531),
    ),
  );

  /// Looks a seed up by id; unknown ids (e.g. from an old install)
  /// fall back to the default royal seed instead of throwing.
  static ThemeSeed fromId(String? id) {
    for (final seed in values) {
      if (seed.id == id) return seed;
    }
    return royal;
  }
}
