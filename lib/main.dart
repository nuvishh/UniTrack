import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/theme_provider.dart';
import 'screens/fleet_list_screen.dart';
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

class UniTrackApp extends ConsumerWidget {
  const UniTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    return MaterialApp(
      title: 'UniTrack',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const FleetListScreen(),
    );
  }
}
