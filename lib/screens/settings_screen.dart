import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/saved_vehicle.dart';
import '../providers/registry_provider.dart';
import '../providers/saved_vehicles_provider.dart';
import '../providers/storage_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/tracker_provider.dart';
import '../services/backup_service.dart';
import '../services/provider_registry_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/vehicle_category_icon.dart';

/// Settings: appearance, refresh interval, saved vehicles, provider
/// status, backup & restore, and app info.
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

  /// Exports every saved vehicle + its credentials as one JSON file
  /// and opens the share sheet. A warning is shown first: the file
  /// contains API keys and passwords in plain text.
  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final storage = ref.read(secureStorageServiceProvider);
    final vehicles = await ref.read(savedVehiclesProvider.future);
    final items = <BackupVehicle>[];
    for (final vehicle in vehicles) {
      final secret = await storage.readSecret(vehicle.id);
      if (secret == null || secret.isEmpty) continue;
      items.add(
        BackupVehicle(
          providerKey: vehicle.providerKey,
          deviceId: vehicle.deviceId,
          secret: secret,
          regNo: vehicle.regNo,
          displayName: vehicle.displayName,
          category: vehicle.category,
        ),
      );
    }
    if (!context.mounted) return;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to back up yet.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export contains your keys'),
        content: Text(
          'This backup file contains your API keys and passwords in '
          'plain text — ${items.length} vehicle${items.length == 1 ? '' : 's'}. '
          'Anyone with the file can track your vehicles.\n\n'
          'Keep it private: store it somewhere safe and never send '
          'it to anyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Export anyway'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final filename = 'unitrack-backup-$stamp.json';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(buildBackupJson(items)),
            name: filename,
            mimeType: 'application/json',
          ),
        ],
      ),
    );
  }

  /// Imports a backup JSON file: validates strictly, skips
  /// duplicates, restores the rest, then refreshes the fleet.
  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked.isEmpty || !context.mounted) return;
    Uint8List bytes;
    try {
      bytes = await picked.first.readAsBytes();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read that file.')),
      );
      return;
    }
    List<BackupVehicle> imported;
    try {
      imported = parseBackup(utf8.decode(bytes));
    } on BackupFormatException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read this backup file.'),
        ),
      );
      return;
    }
    final existing = await ref.read(savedVehiclesProvider.future);
    final plan = planImport(
      existing
          .map(
            (v) => BackupVehicle(
              providerKey: v.providerKey,
              deviceId: v.deviceId,
              secret: '',
            ),
          )
          .toList(),
      imported,
    );
    final storage = ref.read(secureStorageServiceProvider);
    final base = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < plan.fresh.length; i++) {
      final vehicle = plan.fresh[i];
      await storage.saveVehicle(
        SavedVehicle(
          id: '${base + i}',
          providerKey: vehicle.providerKey,
          deviceId: vehicle.deviceId,
          regNo: vehicle.regNo,
          displayName: vehicle.displayName,
          category: vehicle.category,
        ),
        vehicle.secret,
      );
    }
    ref.invalidate(savedVehiclesProvider);
    await ref.read(trackerProvider.notifier).refreshAll();
    if (!context.mounted) return;
    final importedCount = plan.fresh.length;
    final message = importedCount == 0
        ? plan.skipped == 0
              ? 'This backup has no vehicles to import.'
              : 'Nothing new — all ${plan.skipped} vehicle${plan.skipped == 1 ? '' : 's'} '
                    'are already saved.'
        : '$importedCount imported'
              '${plan.skipped == 0 ? '' : ', ${plan.skipped} skipped as duplicate${plan.skipped == 1 ? '' : 's'}'}.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    final descriptors = ref.watch(providerDescriptorsProvider);
    final descriptorByKey = {for (final d in descriptors) d.key: d};
    final registryState = ref.watch(registryProvider);

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
          const SectionHeader(title: 'Backup & restore'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reinstalling the app wipes saved vehicles and '
                    'credentials. Export a backup first, then import it '
                    'after reinstalling.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _exportBackup(context, ref),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Export configuration'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _importBackup(context, ref),
                      icon: const Icon(Icons.upload_outlined),
                      label: const Text('Import configuration'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The backup file contains your API keys and '
                    'passwords in plain text — keep it private and '
                    'never send it to anyone.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
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
                  final displayName =
                      descriptorByKey[vehicle.providerKey]?.displayName ??
                      vehicle.providerKey;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: VehicleCategoryIcon(
                          category: vehicle.category,
                          size: 24,
                          color: AppColors.providerColor(vehicle.providerKey),
                          tileColor: AppColors.providerColor(
                            vehicle.providerKey,
                          ).withValues(alpha: 0.14),
                        ),
                        title: Text(vehicle.displayName ?? vehicle.deviceId),
                        subtitle: Text(
                          '$displayName · ${vehicle.deviceId}',
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
          SectionHeader(
            title: 'Providers',
            trailing: TextButton.icon(
              onPressed: registryState.isRefreshing
                  ? null
                  : () async {
                      final ok = await ref
                          .read(registryProvider.notifier)
                          .refresh();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Provider list updated.'
                                : 'Could not reach the provider list — '
                                      'using the built-in providers.',
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh providers'),
            ),
          ),
          if (registryState.registry != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                registryState.source == RegistrySource.remote
                    ? 'Provider list fetched just now (v${registryState.registry!.version}).'
                    : 'Provider list from cache '
                          '(v${registryState.registry!.version}) — '
                          'refreshed every 24h.',
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Using the built-in providers — the remote provider '
                'list could not be loaded (offline or unavailable).',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ...descriptors.map(
            (descriptor) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.providerColor(descriptor.key)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.satellite_alt_outlined,
                      color: AppColors.providerColor(descriptor.key),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(descriptor.displayName)),
                      if (descriptor.isRemote)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Remote',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(descriptor.rateLimitNote),
                  trailing: ProviderStatusPill(descriptor: descriptor),
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
                              'Version 1.2.1 (build 12)',
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
                    'Aargee, LiveTrace, MercyDataTrack, MercyDataTrack '
                    '(4G), PauldeaTrack, SimplyTrack and HashTrace.',
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
