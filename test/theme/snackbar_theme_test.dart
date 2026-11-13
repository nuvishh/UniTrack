import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/theme/app_theme.dart';

/// Regression test for the unreadable-toast bug (2026-11-12): the snackbar
/// background used `ink`, which is near-white in the dark theme, so the
/// white snackbar text was white-on-white and unreadable.
///
/// Material You (v1.3.0): the snackbar uses the M3 inverse surface —
/// dark bg + light text in light mode, LIGHT bg + DARK text in dark
/// mode. The invariant is contrast between background and text, not
/// "dark background", so this test asserts the background matches the
/// theme's inverseSurface, the text matches onInverseSurface, and the
/// two differ in luminance by a wide margin in both modes.
void main() {
  group('snackbar text contrast', () {
    for (final theme in [AppTheme.dark, AppTheme.light]) {
      final brightness = theme.brightness == Brightness.dark
          ? 'dark'
          : 'light';
      test('$brightness theme: inverse-surface background, readable text', () {
        final background = theme.snackBarTheme.backgroundColor;
        final textColor = theme.snackBarTheme.contentTextStyle?.color;
        expect(background, isNotNull, reason: 'snackbar needs a background');
        expect(textColor, isNotNull, reason: 'snackbar needs a text color');
        // The snackbar must use the theme's inverse surface, not a
        // hard-coded dark colour (a hard-coded dark bg is unreadable
        // in dark mode, where the inverse surface is light).
        expect(
          background,
          theme.colorScheme.inverseSurface,
          reason: '$brightness snackbar background must be the inverse surface',
        );
        expect(
          textColor,
          theme.colorScheme.onInverseSurface,
          reason: '$brightness snackbar text must be the inverse-on-surface',
        );
        // And the two must actually contrast.
        final bgLuminance = background!.computeLuminance();
        final textLuminance = textColor!.computeLuminance();
        expect(
          (bgLuminance - textLuminance).abs(),
          greaterThan(0.5),
          reason:
              '$brightness snackbar background ($bgLuminance) and text '
              '($textLuminance) must contrast',
        );
      });
    }
  });
}
