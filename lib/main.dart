import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

/// UniTrack — one app to track vehicles from different GPS providers,
/// each through its own API. See README.md for the provider table.
///
/// State management: Riverpod. Shared state lives in providers under
/// lib/providers/ (tracker + theme); screens watch it with
/// `ref.watch` and trigger actions with `ref.read`. Local, ephemeral
/// widget state (search text, filter chips, wizard steps) still uses
/// plain setState — see README.md.
void main() {
  runApp(const ProviderScope(child: UniTrackApp()));
}

/// The app root: light/dark + seed themes from the theme providers,
/// locale from the locale provider.
class UniTrackApp extends ConsumerStatefulWidget {
  const UniTrackApp({super.key});

  @override
  ConsumerState<UniTrackApp> createState() => _UniTrackAppState();
}

class _UniTrackAppState extends ConsumerState<UniTrackApp> {
  @override
  void initState() {
    super.initState();
    // Vehicle-alert notifications (v1.4.0): initialise the plugin
    // once, on the same instance the tracker notifier reads. The
    // Android 13+ permission prompt appears on first launch.
    unawaited(ref.read(notificationServiceProvider).ensureInitialized());
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final seed = ref.watch(themeSeedProvider);
    final appLocale = ref.watch(localeProvider);
    return MaterialApp(
      title: 'UniTrack',
      theme: AppTheme.lightFor(seed),
      darkTheme: AppTheme.darkFor(seed),
      themeMode: themeMode,
      // Localisation (v1.4.0): English + Malayalam. `locale: null`
      // follows the device; the locale provider's System choice
      // passes null through.
      locale: appLocale.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}
