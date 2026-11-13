import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unitrack/models/theme_seed.dart';
import 'package:unitrack/providers/theme_provider.dart';
import 'package:unitrack/theme/app_theme.dart';

void main() {
  group('ThemeSeed model', () {
    test('has exactly four seeds with unique ids', () {
      expect(ThemeSeed.values.length, 4);
      final ids = ThemeSeed.values.map((s) => s.id).toSet();
      expect(ids.length, 4);
      expect(
        ids,
        containsAll(['ocean', 'sage', 'indigo', 'terracotta']),
      );
    });

    test('ocean is the default seed', () {
      expect(ThemeSeed.ocean.id, 'ocean');
      expect(ThemeSeed.ocean.name, 'Ocean Slate');
      expect(ThemeSeed.fromId(null), ThemeSeed.ocean);
      expect(ThemeSeed.fromId('nope'), ThemeSeed.ocean);
      expect(ThemeSeed.fromId('sage'), ThemeSeed.sage);
      expect(ThemeSeed.fromId('indigo'), ThemeSeed.indigo);
      expect(ThemeSeed.fromId('terracotta'), ThemeSeed.terracotta);
    });

    test('each seed has its own light and dark primary', () {
      // No two seeds share a primary in either brightness — a seed
      // must not silently reuse another seed's surfaces.
      final lightPrimaries =
          ThemeSeed.values.map((s) => s.light.primary).toSet();
      final darkPrimaries =
          ThemeSeed.values.map((s) => s.dark.primary).toSet();
      expect(lightPrimaries.length, 4);
      expect(darkPrimaries.length, 4);
    });
  });

  group('seed-parameterised theme', () {
    test('every seed builds valid light and dark themes', () {
      for (final seed in ThemeSeed.values) {
        final light = AppTheme.lightFor(seed);
        final dark = AppTheme.darkFor(seed);

        expect(light.brightness, Brightness.light);
        expect(dark.brightness, Brightness.dark);

        // The theme carries the seed's own values in each brightness.
        expect(light.colorScheme.primary, seed.light.primary);
        expect(light.colorScheme.surface, seed.light.surface);
        expect(light.colorScheme.onSurface, seed.light.onSurface);
        expect(
          light.colorScheme.secondaryContainer,
          seed.light.secondaryContainer,
        );
        expect(dark.colorScheme.primary, seed.dark.primary);
        expect(dark.colorScheme.surface, seed.dark.surface);
        expect(dark.colorScheme.onSurface, seed.dark.onSurface);
        expect(
          dark.colorScheme.secondaryContainer,
          seed.dark.secondaryContainer,
        );

        // M3 nav: active pill is secondaryContainer.
        expect(
          light.navigationBarTheme.indicatorColor,
          seed.light.secondaryContainer,
        );
        expect(
          dark.navigationBarTheme.indicatorColor,
          seed.dark.secondaryContainer,
        );
      }
    });

    test('the ocean defaults match the prototype values', () {
      final light = AppTheme.light;
      final dark = AppTheme.dark;
      expect(light.colorScheme.primary, const Color(0xFF0F4C5C));
      expect(light.colorScheme.surface, const Color(0xFFF8FAFC));
      expect(dark.colorScheme.primary, const Color(0xFF7AD5F5));
      expect(dark.colorScheme.surface, const Color(0xFF0D1417));
    });

    test('snackbar stays readable for every seed in both modes', () {
      for (final seed in ThemeSeed.values) {
        for (final theme in [AppTheme.lightFor(seed), AppTheme.darkFor(seed)]) {
          final bg = theme.snackBarTheme.backgroundColor!;
          final fg = theme.snackBarTheme.contentTextStyle!.color!;
          // M3 inverse surface, never a hard-coded dark background.
          expect(bg, theme.colorScheme.inverseSurface);
          expect(fg, theme.colorScheme.onInverseSurface);
          expect(
            (bg.computeLuminance() - fg.computeLuminance()).abs(),
            greaterThan(0.5),
            reason: 'snackbar text unreadable for ${seed.id} '
                '${theme.brightness}',
          );
        }
      }
    });
  });

  group('ThemeSeedNotifier persistence', () {
    test('defaults to ocean', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeSeedProvider), ThemeSeed.ocean);
    });

    test('setSeed updates state and persists the choice', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeSeedProvider.notifier).setSeed(ThemeSeed.sage);

      expect(container.read(themeSeedProvider), ThemeSeed.sage);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeSeedNotifier.prefsKey), 'sage');
    });

    test('loads a previously saved seed', () async {
      SharedPreferences.setMockInitialValues({
        ThemeSeedNotifier.prefsKey: 'terracotta',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Reading the provider starts the background load.
      expect(container.read(themeSeedProvider), ThemeSeed.ocean);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(container.read(themeSeedProvider), ThemeSeed.terracotta);
    });

    test('an unknown saved seed id falls back to ocean', () async {
      SharedPreferences.setMockInitialValues({
        ThemeSeedNotifier.prefsKey: 'neon',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeSeedProvider), ThemeSeed.ocean);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(container.read(themeSeedProvider), ThemeSeed.ocean);
    });
  });
}
