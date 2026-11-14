import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/l10n/app_localizations.dart';

void main() {
  group('AppLocalizations', () {
    test('every key exists in both locales with a non-empty value', () {
      for (final key in AppLocalizations.allKeys) {
        final en = AppLocalizations.valueFor('en', key);
        final ml = AppLocalizations.valueFor('ml', key);
        expect(en, isNotNull, reason: 'missing en value for $key');
        expect(en, isNotEmpty, reason: 'empty en value for $key');
        expect(ml, isNotNull, reason: 'missing ml value for $key');
        expect(ml, isNotEmpty, reason: 'empty ml value for $key');
      }
    });

    test('falls back to English for an unknown locale', () {
      final l10n = AppLocalizations(const Locale('fr'));
      expect(l10n.languageCode, 'en');
      expect(l10n.navFleet, 'Fleet');
    });

    test('Malayalam strings are the expected translations', () {
      final l10n = AppLocalizations(const Locale('ml'));
      expect(l10n.navFleet, 'ഫ്ലീറ്റ്');
      expect(l10n.navMap, 'മാപ്പ്');
      expect(l10n.navAdd, 'ചേർക്കുക');
      expect(l10n.navSettings, 'ക്രമീകരണങ്ങൾ');
      expect(l10n.filterLive, 'ലൈവ്');
      expect(l10n.filterIdle, 'നിഷ്ക്രിയം');
      expect(l10n.filterOffline, 'ഓഫ്‌ലൈൻ');
      expect(l10n.testConnection, 'കണക്ഷൻ പരിശോധിക്കുക');
      expect(l10n.vehicleAlerts, 'വാഹന അലേർട്ടുകൾ');
    });

    test('relative time is localised', () {
      final now = DateTime(2026, 11, 13, 12, 0);
      final ml = AppLocalizations(const Locale('ml'));
      expect(
        ml.relativeTime(now.subtract(const Duration(seconds: 10)), now: now),
        'ഇപ്പോൾ',
      );
      expect(
        ml.relativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5 മിനിറ്റ് മുമ്പ്',
      );
      expect(
        ml.relativeTime(now.subtract(const Duration(hours: 2)), now: now),
        '2 മണിക്കൂർ മുമ്പ്',
      );
      expect(
        ml.relativeTime(now.subtract(const Duration(days: 3)), now: now),
        '3 ദിവസം മുമ്പ്',
      );
      final en = AppLocalizations(const Locale('en'));
      expect(
        en.relativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5 min ago',
      );
      expect(
        en.relativeTime(now.subtract(const Duration(hours: 1)), now: now),
        '1 hour ago',
      );
      expect(
        en.relativeTime(now.subtract(const Duration(days: 1)), now: now),
        '1 day ago',
      );
    });

    test('count chips and fleet subtitle pluralise', () {
      final en = AppLocalizations(const Locale('en'));
      expect(en.countChip('Live', 3), 'Live (3)');
      expect(en.fleetSubtitle(1, 1), '1 vehicle · 1 provider');
      expect(en.fleetSubtitle(3, 2), '3 vehicles · 2 providers');
    });

    test('delegate supports only en and ml', () {
      expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
      expect(AppLocalizations.delegate.isSupported(const Locale('ml')), isTrue);
      expect(
        AppLocalizations.delegate.isSupported(const Locale('fr')),
        isFalse,
      );
    });

    testWidgets('of() falls back to English when no delegate is in the tree', (
      tester,
    ) async {
      String? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              seen = AppLocalizations.of(context).navFleet;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, 'Fleet');
    });

    testWidgets('of() returns Malayalam when the app locale is ml', (
      tester,
    ) async {
      String? seen;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ml'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              seen = AppLocalizations.of(context).navFleet;
              return const SizedBox();
            },
          ),
        ),
      );
      // The delegates load asynchronously — one more pump lets the
      // localised tree build.
      await tester.pump();
      expect(seen, 'ഫ്ലീറ്റ്');
    });
  });
}
