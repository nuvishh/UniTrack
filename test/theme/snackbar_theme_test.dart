import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/theme/app_theme.dart';

/// Regression test for the unreadable-toast bug (2026-11-12): the snackbar
/// background used `ink`, which is near-white in the dark theme, so the
/// white snackbar text was white-on-white and unreadable. The background
/// must stay dark enough in both themes for white text to read.
void main() {
  group('snackbar text contrast', () {
    for (final theme in [AppTheme.dark, AppTheme.light]) {
      final brightness = theme.brightness == Brightness.dark
          ? 'dark'
          : 'light';
      test('$brightness theme: white text on dark background', () {
        final background = theme.snackBarTheme.backgroundColor;
        final textColor = theme.snackBarTheme.contentTextStyle?.color;
        expect(background, isNotNull, reason: 'snackbar needs a background');
        expect(textColor, isNotNull, reason: 'snackbar needs a text color');
        // Dark background (luminance well under 0.5) + light text
        // (luminance well over 0.5) so the message stays readable.
        expect(
          background!.computeLuminance(),
          lessThan(0.25),
          reason: '$brightness snackbar background must be dark',
        );
        expect(
          textColor!.computeLuminance(),
          greaterThan(0.7),
          reason: '$brightness snackbar text must be light',
        );
      });
    }
  });
}
