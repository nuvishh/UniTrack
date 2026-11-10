import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unitrack/providers/theme_provider.dart';

void main() {
  test('defaults to following the system', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeProvider), ThemeMode.system);
  });

  test('setMode updates state and persists the choice', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeProvider.notifier).setMode(ThemeMode.dark);

    expect(container.read(themeProvider), ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeNotifier.prefsKey), 'dark');
  });

  test('loads a previously saved mode', () async {
    SharedPreferences.setMockInitialValues({ThemeNotifier.prefsKey: 'dark'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Reading the provider starts the background load.
    expect(container.read(themeProvider), ThemeMode.system);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(container.read(themeProvider), ThemeMode.dark);
  });

  test('an unknown saved value falls back to system', () async {
    SharedPreferences.setMockInitialValues({ThemeNotifier.prefsKey: 'neon'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Reading the provider starts the background load.
    expect(container.read(themeProvider), ThemeMode.system);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(container.read(themeProvider), ThemeMode.system);
  });
}
