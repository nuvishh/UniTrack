import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unitrack/providers/locale_provider.dart';

void main() {
  test('defaults to following the system', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(localeProvider), AppLocale.system);
  });

  test('setLocale updates state and persists the choice', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(localeProvider.notifier)
        .setLocale(AppLocale.malayalam);

    expect(container.read(localeProvider), AppLocale.malayalam);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(LocaleNotifier.prefsKey), 'malayalam');
  });

  test('loads a previously saved locale', () async {
    SharedPreferences.setMockInitialValues({
      LocaleNotifier.prefsKey: 'english',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Reading the provider starts the background load.
    expect(container.read(localeProvider), AppLocale.system);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(container.read(localeProvider), AppLocale.english);
  });

  test('an unknown saved value falls back to system', () async {
    SharedPreferences.setMockInitialValues({
      LocaleNotifier.prefsKey: 'klingon',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(localeProvider), AppLocale.system);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(container.read(localeProvider), AppLocale.system);
  });

  test('system maps to a null MaterialApp locale, others map to en/ml', () {
    expect(AppLocale.system.locale, isNull);
    expect(AppLocale.english.locale!.languageCode, 'en');
    expect(AppLocale.malayalam.locale!.languageCode, 'ml');
  });
}
