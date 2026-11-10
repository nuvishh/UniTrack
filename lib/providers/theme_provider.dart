import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
