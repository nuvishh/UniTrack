import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's language: follow the device, or force English/Malayalam.
///
/// Persisted in SharedPreferences under [LocaleNotifier.prefsKey].
/// The value is a [Locale] for [MaterialApp]: `null` means "follow
/// the system" ([AppLocale.system]).
enum AppLocale {
  system,
  english,
  malayalam;

  /// The [Locale] to hand to [MaterialApp], or null to follow the
  /// system locale.
  Locale? get locale => switch (this) {
    AppLocale.system => null,
    AppLocale.english => const Locale('en'),
    AppLocale.malayalam => const Locale('ml'),
  };

  static AppLocale fromName(String? name) => AppLocale.values.firstWhere(
    (v) => v.name == name,
    orElse: () => AppLocale.system,
  );
}

/// Owns the app's language and persists it.
///
/// Same mechanism as [ThemeNotifier]: SharedPreferences, key
/// `unitrack_locale_v1`. Unknown stored values fall back to System.
class LocaleNotifier extends Notifier<AppLocale> {
  /// SharedPreferences key for the saved locale name.
  static const prefsKey = 'unitrack_locale_v1';

  @override
  AppLocale build() {
    // Load the saved locale in the background; the app follows the
    // system until it arrives.
    unawaited(_load());
    return AppLocale.system;
  }

  Future<void> setLocale(AppLocale value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, value.name);
  }

  Future<void> _load() async {
    // A failed load (e.g. no platform in a unit test) keeps the
    // default — never let a storage error break the app start.
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      state = AppLocale.fromName(prefs.getString(prefsKey));
    } catch (_) {
      // Keep the default (System).
    }
  }
}

/// The app's language choice for the whole app.
final localeProvider = NotifierProvider<LocaleNotifier, AppLocale>(
  LocaleNotifier.new,
);
