import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/alert.dart';
import '../providers/alerts_provider.dart';
import '../providers/geofences_provider.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/app_widgets.dart';

/// Alerts (Volty-style): the locally detected event feed.
///
/// Filter chips: All / Ignition / Overspeed / Geofence. No SOS chip —
/// no provider reports SOS, so SOS alerts are never invented.
/// Each card carries a severity pill and a "View on Map" action that
/// centres the Map tab on the vehicle. Alert Settings opens the
/// overspeed threshold + geofence manager.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

enum _AlertFilter { all, ignition, overspeed, geofence }

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  _AlertFilter _filter = _AlertFilter.all;

  List<FleetAlert> _filtered(List<FleetAlert> alerts) {
    return switch (_filter) {
      _AlertFilter.all => alerts,
      _AlertFilter.ignition => alerts
          .where(
            (a) =>
                a.type == AlertType.ignitionOn ||
                a.type == AlertType.ignitionOff,
          )
          .toList(),
      _AlertFilter.overspeed => alerts
          .where((a) => a.type == AlertType.overspeed)
          .toList(),
      _AlertFilter.geofence => alerts
          .where(
            (a) =>
                a.type == AlertType.geofenceEnter ||
                a.type == AlertType.geofenceExit,
          )
          .toList(),
    };
  }

  Future<void> _export(List<FleetAlert> alerts) async {
    final buffer = StringBuffer()
      ..writeln('UniTrack alerts')
      ..writeln('Time,Type,Severity,Vehicle,Detail');
    for (final alert in alerts) {
      buffer.writeln(
        '${alert.time.toIso8601String()},${alert.type.name},'
        '${alert.severityLabel},${alert.vehicleName},'
        '"${(alert.message ?? '').replaceAll('"', "'")}"',
      );
    }
    await SharePlus.instance.share(
      ShareParams(text: buffer.toString(), subject: 'unitrack-alerts.csv'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alerts shared — save them from the share sheet.'),
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AlertSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alertsState = ref.watch(alertsProvider);
    final alerts = alertsState.alerts;
    final filtered = _filtered(alerts);
    final ignitionCount = alerts
        .where(
          (a) =>
              a.type == AlertType.ignitionOn ||
              a.type == AlertType.ignitionOff,
        )
        .length;
    final overspeedCount = alerts
        .where((a) => a.type == AlertType.overspeed)
        .length;
    final geofenceCount = alerts
        .where(
          (a) =>
              a.type == AlertType.geofenceEnter ||
              a.type == AlertType.geofenceExit,
        )
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Alert settings',
            onPressed: _openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Export alerts',
            onPressed: filtered.isEmpty ? null : () => _export(filtered),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  count: alerts.length,
                  icon: Icons.list_alt_outlined,
                  selected: _filter == _AlertFilter.all,
                  onTap: () => setState(() => _filter = _AlertFilter.all),
                ),
                _FilterChip(
                  label: 'Ignition',
                  count: ignitionCount,
                  icon: Icons.power_settings_new_outlined,
                  selected: _filter == _AlertFilter.ignition,
                  onTap: () =>
                      setState(() => _filter = _AlertFilter.ignition),
                ),
                _FilterChip(
                  label: 'Overspeed',
                  count: overspeedCount,
                  icon: Icons.speed_outlined,
                  selected: _filter == _AlertFilter.overspeed,
                  onTap: () =>
                      setState(() => _filter = _AlertFilter.overspeed),
                ),
                _FilterChip(
                  label: 'Geofence',
                  count: geofenceCount,
                  icon: Icons.place_outlined,
                  selected: _filter == _AlertFilter.geofence,
                  onTap: () =>
                      setState(() => _filter = _AlertFilter.geofence),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.history, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Showing ${filtered.length} alert${filtered.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    icon: Icons.notifications_none_outlined,
                    title: 'No alerts yet',
                    message: _filter == _AlertFilter.all
                        ? 'Ignition changes, overspeed and geofence '
                              'crossings will appear here as the fleet '
                              'polls.'
                        : 'Nothing in this category yet.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AlertCard(alert: filtered[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.14)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                '$label ($count)',
                style: TextStyle(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends ConsumerWidget {
  const _AlertCard({required this.alert});

  final FleetAlert alert;

  (IconData, Color) _visual() {
    return switch (alert.type) {
      AlertType.ignitionOn => (
        Icons.power_settings_new,
        AppColors.live,
      ),
      AlertType.ignitionOff => (
        Icons.power_settings_new,
        AppColors.expired,
      ),
      AlertType.overspeed => (Icons.speed_outlined, AppColors.idle),
      AlertType.geofenceEnter => (
        Icons.place_outlined,
        AppColors.providerColor('hashtrace'),
      ),
      AlertType.geofenceExit => (
        Icons.place_outlined,
        AppColors.providerColor('hashtrace'),
      ),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (icon, color) = _visual();
    final severityColor = switch (alert.severity) {
      AlertSeverity.low => AppColors.unknown,
      AlertSeverity.medium => AppColors.idle,
      AlertSeverity.high => AppColors.expired,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(alert.title, style: theme.textTheme.titleMedium),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    alert.severityLabel,
                    style: TextStyle(
                      color: severityColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (alert.message != null) ...[
              const SizedBox(height: 8),
              Text(alert.message!, style: theme.textTheme.bodyMedium),
            ],
            if (alert.latitude != null && alert.longitude != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${alert.latitude!.toStringAsFixed(5)}, '
                      '${alert.longitude!.toStringAsFixed(5)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  formatAlertTime(alert.time),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {
                    ref
                        .read(homeNavProvider.notifier)
                        .focusVehicleOnMap(alert.vehicleKey);
                  },
                  icon: const Icon(Icons.location_on_outlined, size: 18),
                  label: const Text('View on Map'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: overspeed threshold, geofence list, clear history.
/// No SOS settings — no provider reports SOS.
class _AlertSettingsSheet extends ConsumerWidget {
  const _AlertSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final alertsState = ref.watch(alertsProvider);
    final geofences = ref.watch(geofencesProvider);
    final threshold = alertsState.overspeedThresholdKmh;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Alert settings', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Overspeed limit', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<double>(
              segments: [60, 80, 100, 120]
                  .map(
                    (v) => ButtonSegment(
                      value: v.toDouble(),
                      label: Text('$v'),
                    ),
                  )
                  .toList(),
              selected: {threshold},
              onSelectionChanged: (selected) {
                ref
                    .read(alertsProvider.notifier)
                    .setOverspeedThreshold(selected.first);
              },
            ),
            const SizedBox(height: 4),
            Text(
              'An alert fires when a vehicle crosses above '
              '${threshold.toStringAsFixed(0)} km/h.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Text(
              'Geofences (${geofences.length})',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (geofences.isEmpty)
              const Text(
                'No geofences yet — add one from a vehicle\'s detail '
                'screen, at its current location.',
              )
            else
              ...geofences.map(
                (fence) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(fence.name),
                    subtitle: Text(
                      '${fence.radiusLabel} · ${fence.vehicleKey}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove geofence',
                      onPressed: () => ref
                          .read(geofencesProvider.notifier)
                          .remove(fence.id),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(alertsProvider.notifier).clearAll();
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Clear alert history'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'SOS alerts are not available — no GPS provider reports SOS.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
