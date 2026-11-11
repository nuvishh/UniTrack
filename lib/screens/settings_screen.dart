import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gps_provider.dart';
import '../models/saved_vehicle.dart';
import '../providers/saved_vehicles_provider.dart';
import '../providers/storage_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/tracker_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Settings: appearance, refresh interval, saved vehicles, provider
/// status and app info.
///
/// Everything here is shared state from providers — theme from
/// [themeProvider], the refresh interval from [trackerProvider], the
/// saved vehicles from [savedVehiclesProvider] — so there is no
/// setState left in this screen at all.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _intervals = [
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

  String _intervalLabel(Duration interval) {
    if (interval.inSeconds < 60) return '${interval.inSeconds}s';
    if (interval.inMinutes == 1) return '1 min';
    return '${interval.inMinutes} min';
  }

  String _intervalPlainLabel(Duration interval) {
    if (interval.inSeconds < 60) {
      return 'Every ${interval.inSeconds} seconds';
    }
    if (interval.inMinutes == 1) return 'Every minute';
    return 'Every ${interval.inMinutes} minutes';
  }

  Future<void> _deleteVehicle(
    BuildContext context,
    WidgetRef ref,
    SavedVehicle vehicle,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove vehicle?'),
        content: Text(
          'Remove ${vehicle.displayName ?? vehicle.deviceId} and delete '
          'its stored credentials?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(secureStorageServiceProvider).deleteVehicle(vehicle.id);
    ref.invalidate(savedVehiclesProvider);
    await ref.read(trackerProvider.notifier).refreshAll();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final refreshInterval = ref.watch(
      trackerProvider.select((s) => s.refreshInterval),
    );
    final savedVehicles = ref.watch(savedVehiclesProvider);
    final savedCount = switch (savedVehicles) {
      AsyncData(:final value) => value.length,
      _ => 0,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SectionHeader(title: 'Appearance'),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Dark'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.phone_android_outlined),
                label: Text('System'),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (selected) {
              ref.read(themeProvider.notifier).setMode(selected.first);
            },
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Refresh interval'),
          SegmentedButton<Duration>(
            segments: _intervals
                .map(
                  (interval) => ButtonSegment(
                    value: interval,
                    label: Text(_intervalLabel(interval)),
                  ),
                )
                .toList(),
            selected: {refreshInterval},
            onSelectionChanged: (selected) {
              ref
                  .read(trackerProvider.notifier)
                  .setRefreshInterval(selected.first);
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${_intervalPlainLabel(refreshInterval)} — '
            'providers enforce their own minimum poll interval on top '
            'of this (SimplyTrack: 60s, Aargee: 60s).',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Saved vehicles',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$savedCount',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          savedVehicles.when(
            data: (vehicles) {
              if (vehicles.isEmpty) {
                return const EmptyState(
                  icon: Icons.directions_bus_outlined,
                  title: 'No vehicles saved yet',
                  message:
                      'Vehicles you add will appear here, with their '
                      'provider and device ID.',
                );
              }
              return Column(
                children: vehicles.map((vehicle) {
                  final provider = GpsProvider.fromKey(vehicle.providerKey);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.providerColor(vehicle.providerKey)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.directions_bus_outlined,
                            color: AppColors.providerColor(vehicle.providerKey),
                          ),
                        ),
                        title: Text(vehicle.displayName ?? vehicle.deviceId),
                        subtitle: Text(
                          '${provider.displayName} · ${vehicle.deviceId}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove',
                          onPressed: () =>
                              _deleteVehicle(context, ref, vehicle),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => ErrorStateCard(
              message: "Couldn't load the saved vehicles. $error",
              onRetry: () => ref.invalidate(savedVehiclesProvider),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Providers'),
          ...GpsProvider.values.map(
            (provider) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.providerColor(provider.key)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.satellite_alt_outlined,
                      color: AppColors.providerColor(provider.key),
                    ),
                  ),
                  title: Text(provider.displayName),
                  subtitle: Text(provider.rateLimitNote),
                  trailing: ProviderStatusPill(provider: provider),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'About'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('UniTrack', style: theme.textTheme.titleLarge),
                            Text(
                              'Version 1.0.7 (build 8)',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Universal GPS tracker — one fleet across Transight, '
                    'Aargee, LiveTrace, MercyDataTrack, PauldeaTrack, '
                    'SimplyTrack and HashTrace.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Credentials are stored only on this device, in '
                    'secure storage. No backend, no analytics.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
