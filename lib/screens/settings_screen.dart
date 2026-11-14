import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/saved_vehicle.dart';
import '../models/theme_seed.dart';
import '../providers/locale_provider.dart';
import '../providers/maps_provider.dart';
import '../providers/notification_provider.dart';
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

/// Settings: appearance, language, notifications, refresh interval,
/// saved vehicles, provider status, backup & restore, and app info.
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

  /// Text shared by the "Share UniTrack" row: app name, one-liner,
  /// and the releases page.
  static const _shareText =
      'UniTrack – Universal GPS Tracker\n'
      'Track all your vehicles in one app.\n'
      'https://github.com/nuvishh/UniTrack/releases';

  Future<void> _deleteVehicle(
    BuildContext context,
    WidgetRef ref,
    SavedVehicle vehicle,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeVehicleTitle),
        content: Text(
          l10n.removeVehicleContent(vehicle.displayName ?? vehicle.deviceId),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.remove),
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
    final l10n = AppLocalizations.of(context);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.nothingToBackup)));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.exportKeysTitle),
        content: Text(l10n.exportKeysContent(items.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.exportAnyway),
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
    final l10n = AppLocalizations.of(context);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.couldNotReadFile)));
      return;
    }
    List<BackupVehicle> imported;
    try {
      imported = parseBackup(utf8.decode(bytes));
    } on BackupFormatException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.couldNotReadBackup)));
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
              ? l10n.backupNoVehicles
              : l10n.backupNothingNew(plan.skipped)
        : l10n.importResultMessage(importedCount, plan.skipped);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Shares the app link (releases page) via the system share sheet.
  Future<void> _shareApp() async {
    await SharePlus.instance.share(ShareParams(text: _shareText));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeProvider);
    final themeSeed = ref.watch(themeSeedProvider);
    final appLocale = ref.watch(localeProvider);
    final alertSettings = ref.watch(alertSettingsProvider);
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsTitle),
            Text(
              l10n.settingsSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionHeader(title: l10n.appearance),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.light,
                icon: const Icon(Icons.light_mode_outlined),
                label: Text(l10n.themeLight),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: const Icon(Icons.dark_mode_outlined),
                label: Text(l10n.themeDark),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: const Icon(Icons.phone_android_outlined),
                label: Text(l10n.themeSystem),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (selected) {
              ref.read(themeProvider.notifier).setMode(selected.first);
            },
          ),
          const SizedBox(height: 24),
          SectionHeader(title: l10n.colourTheme),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ThemeSeed.values.map((seed) {
              final selected = seed.id == themeSeed.id;
              final scheme = theme.colorScheme;
              return InkWell(
                onTap: () => ref.read(themeSeedProvider.notifier).setSeed(seed),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.secondaryContainer
                        : scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: selected
                        ? Border.all(color: scheme.primary, width: 2)
                        : Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: seed.swatch,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: selected
                            ? Icon(
                                Icons.check,
                                size: 14,
                                color: seed.light.onPrimary,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        seed.name,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: selected
                              ? scheme.onSecondaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(l10n.themeAppliesNote, style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          SectionHeader(title: l10n.language),
          SegmentedButton<AppLocale>(
            segments: [
              ButtonSegment(
                value: AppLocale.system,
                label: Text(l10n.languageSystem),
              ),
              ButtonSegment(
                value: AppLocale.english,
                label: Text(l10n.languageEnglish),
              ),
              ButtonSegment(
                value: AppLocale.malayalam,
                label: Text(l10n.languageMalayalam),
              ),
            ],
            selected: {appLocale},
            onSelectionChanged: (selected) {
              ref.read(localeProvider.notifier).setLocale(selected.first);
            },
          ),
          const SizedBox(height: 24),
          SectionHeader(title: l10n.notifications),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l10n.vehicleAlerts),
                  subtitle: Text(l10n.vehicleAlertsSubtitle),
                  value: alertSettings.master,
                  onChanged: (value) =>
                      ref.read(alertSettingsProvider.notifier).setMaster(value),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(l10n.ignitionChanges),
                  subtitle: Text(l10n.ignitionChangesSubtitle),
                  value: alertSettings.ignition,
                  onChanged: alertSettings.master
                      ? (value) => ref
                            .read(alertSettingsProvider.notifier)
                            .setIgnition(value)
                      : null,
                ),
                SwitchListTile(
                  title: Text(l10n.overspeed),
                  subtitle: Text(l10n.overspeedSubtitle),
                  value: alertSettings.overspeed,
                  onChanged: alertSettings.master
                      ? (value) => ref
                            .read(alertSettingsProvider.notifier)
                            .setOverspeed(value)
                      : null,
                ),
                SwitchListTile(
                  title: Text(l10n.offlineAlerts),
                  subtitle: Text(l10n.offlineAlertsSubtitle),
                  value: alertSettings.offline,
                  onChanged: alertSettings.master
                      ? (value) => ref
                            .read(alertSettingsProvider.notifier)
                            .setOffline(value)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(title: l10n.refreshInterval),
          SegmentedButton<Duration>(
            segments: _intervals
                .map(
                  (interval) => ButtonSegment(
                    value: interval,
                    label: Text(l10n.intervalLabel(interval)),
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
            l10n.refreshIntervalNote(
              refreshInterval.inSeconds < 60
                  ? l10n.everySeconds(refreshInterval.inSeconds)
                  : l10n.everyMinutes(refreshInterval.inMinutes),
            ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          SectionHeader(title: l10n.mapSettings),
          const _GoogleMapsKeyCard(),
          const SizedBox(height: 24),
          SectionHeader(title: l10n.backupRestore),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.backupCardText, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _exportBackup(context, ref),
                      icon: const Icon(Icons.download_outlined),
                      label: Text(l10n.exportConfig),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _importBackup(context, ref),
                      icon: const Icon(Icons.upload_outlined),
                      label: Text(l10n.importConfig),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.backupWarning, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: l10n.savedVehicles,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$savedCount',
                style: TextStyle(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          savedVehicles.when(
            data: (vehicles) {
              if (vehicles.isEmpty) {
                return EmptyState(
                  icon: Icons.directions_bus_outlined,
                  title: l10n.noSavedVehicles,
                  message: l10n.noVehiclesSavedMessage,
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
                        subtitle: Text('$displayName · ${vehicle.deviceId}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: l10n.remove,
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
              message: l10n.couldNotLoadSaved('$error'),
              onRetry: () => ref.invalidate(savedVehiclesProvider),
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: l10n.providers,
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
                                ? l10n.providerListUpdated
                                : l10n.providerListOffline,
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.refreshProviders),
            ),
          ),
          if (registryState.registry != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                registryState.source == RegistrySource.remote
                    ? l10n.providerListRemote(registryState.registry!.version)
                    : l10n.providerListCached(registryState.registry!.version),
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                l10n.providerListBuiltin,
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
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l10n.remoteBadge,
                            style: TextStyle(
                              color: theme.colorScheme.onSecondaryContainer,
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
          SectionHeader(title: l10n.about),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // The new launcher icon (v1.5.0) instead of the
                      // generic pin.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('UniTrack', style: theme.textTheme.titleLarge),
                            Text(
                              l10n.versionLabel('1.5.0 (build 17)'),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.aboutText, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(l10n.aboutPrivacy, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.share_outlined,
                color: theme.colorScheme.primary,
              ),
              title: Text(l10n.shareApp),
              subtitle: Text(l10n.shareAppSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: _shareApp,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Google Maps API key" card (v1.5.0): the user pastes their own
/// key, saved in secure storage like the provider secrets. With a
/// key the Map tab shows Google Maps; without one it stays on
/// OpenStreetMap.
class _GoogleMapsKeyCard extends ConsumerStatefulWidget {
  const _GoogleMapsKeyCard();

  @override
  ConsumerState<_GoogleMapsKeyCard> createState() => _GoogleMapsKeyCardState();
}

class _GoogleMapsKeyCardState extends ConsumerState<_GoogleMapsKeyCard> {
  final _controller = TextEditingController();
  bool _obscured = true;
  bool _showRestartNote = false;

  /// True once the field has been filled from the saved key, so a
  /// late storage load never overwrites what the user typed.
  bool _synced = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final text = _controller.text.trim();
    final applied = await ref
        .read(googleMapsKeyProvider.notifier)
        .setKey(text);
    if (!mounted) return;
    setState(() => _showRestartNote = text.isNotEmpty);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text.isEmpty
              ? l10n.googleMapsKeyRemoved
              : applied
              ? l10n.googleMapsKeySaved
              : l10n.googleMapsKeyApplyFailed,
        ),
      ),
    );
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context);
    _controller.clear();
    await ref.read(googleMapsKeyProvider.notifier).clearKey();
    if (!mounted) return;
    setState(() => _showRestartNote = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.googleMapsKeyRemoved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final savedKey = ref.watch(googleMapsKeyProvider);
    if (!_synced && savedKey != null) {
      _controller.text = savedKey;
      _synced = true;
    }
    final hasKey = savedKey != null && savedKey.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.googleMapsApiKey, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.googleMapsApiKeyHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              obscureText: _obscured,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: l10n.googleMapsApiKeyHint,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  tooltip: _obscured ? l10n.show : l10n.hide,
                  onPressed: () => setState(() => _obscured = !_obscured),
                ),
              ),
              onChanged: (_) => setState(() => _showRestartNote = false),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.key_outlined),
                    label: Text(l10n.saveKey),
                  ),
                ),
                if (hasKey) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.clearKey),
                  ),
                ],
              ],
            ),
            if (_showRestartNote) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.googleMapsRestartNote,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
