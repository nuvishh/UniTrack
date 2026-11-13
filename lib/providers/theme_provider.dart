import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/theme_seed.dart';

/// Owns the app's light/dark mode and persists it.
///
/// Same storage as the old ThemeController: SharedPreferences key
/// `unitrack_theme_mode_v1`, so upgrading keeps the user's choice.
/// Kept separate from [SecureStorageService] on purpose: the theme is
/// a UI preference, not a credential.
class ThemeNotifier extends Notifier<ThemeMode> {
  /// SharedPreferences key for the saved mode.
  static const prefsKey = 'unitrack_theme_mode_v1';

  @override
  ThemeMode build() {
    // Load the saved mode in the background; the app follows the
    // system until it arrives.
    unawaited(_load());
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state = _parse(prefs.getString(prefsKey));
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    await prefs.setString(prefsKey, _encode(mode));
  }

  static ThemeMode _parse(String? raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _encode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

/// The current [ThemeMode] for the whole app.
final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);

/// Owns the app's Material You colour seed and persists it.
///
/// Same mechanism as [ThemeNotifier]: SharedPreferences, key
/// `unitrack_theme_seed_v1`. Unknown stored ids fall back to the
/// default seed (ocean) via [ThemeSeed.fromId], so an old install
/// never breaks. The light/dark toggle from [themeProvider] works
/// with every seed — the seed picks the palette, the mode picks
/// the brightness.
class ThemeSeedNotifier extends Notifier<ThemeSeed> {
  /// SharedPreferences key for the saved seed id.
  static const prefsKey = 'unitrack_theme_seed_v1';

  @override
  ThemeSeed build() {
    // Load the saved seed in the background; the app uses the
    // default (ocean) until it arrives.
    unawaited(_load());
    return ThemeSeed.ocean;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state = ThemeSeed.fromId(prefs.getString(prefsKey));
  }

  Future<void> setSeed(ThemeSeed seed) async {
    state = seed;
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    await prefs.setString(prefsKey, seed.id);
  }
}

/// The current colour [ThemeSeed] for the whole app.
final themeSeedProvider = NotifierProvider<ThemeSeedNotifier, ThemeSeed>(
  ThemeSeedNotifier.new,
);
