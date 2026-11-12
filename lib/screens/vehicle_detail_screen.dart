import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../models/trip_point.dart';
import '../models/vehicle.dart';
import '../providers/registry_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/trip_log_provider.dart';
import '../services/providers/gps_provider_client.dart';
import '../services/trip_summary.dart';
import '../theme/app_theme.dart';
import '../utils/geo.dart';
import '../widgets/app_widgets.dart';
import '../widgets/vehicle_category_icon.dart';
import '../widgets/vehicle_status_chip.dart';
import 'map_screen.dart';

/// Detail for one vehicle: a big live status hero, the key facts, and
/// today's route where the provider supports history.
///
/// The loaded history is local, ephemeral screen state — plain
/// setState. Fetching goes through [trackerProvider].
class VehicleDetailScreen extends ConsumerStatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  ConsumerState<VehicleDetailScreen> createState() =>
      _VehicleDetailScreenState();
}

/// Compact live-location map under the status hero: the vehicle's
/// current position on OpenStreetMap. The map itself is a static
/// preview (it never steals the page scroll); tap anywhere on the
/// card to open the full map.
class _LiveLocationMap extends StatelessWidget {
  const _LiveLocationMap({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final point = LatLng(vehicle.latitude!, vehicle.longitude!);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MapScreen()),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 200,
              child: IgnorePointer(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.nuvish.unitrack',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.location_on,
                            color: AppColors.statusColor(vehicle.status),
                            size: 44,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.map_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Live location — tap for the full map',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen> {
  List<Vehicle>? _history;
  String? _historyError;
  bool _loadingHistory = false;

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final points = await ref
          .read(trackerProvider.notifier)
          .fetchHistoryFor(widget.vehicle, from: startOfDay, to: now);
      if (!mounted) return;
      setState(() => _history = points);
    } on UnsupportedError catch (e) {
      if (!mounted) return;
      setState(() => _historyError = e.message);
    } on ProviderException catch (e) {
      if (!mounted) return;
      setState(() => _historyError = e.message);
    } catch (e) {
      // Timeout / network errors used to be unhandled here.
      if (!mounted) return;
      setState(() => _historyError = 'Could not load history: $e');
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _copyCoordinates() {
    final vehicle = widget.vehicle;
    if (!vehicle.hasFix) return;
    Clipboard.setData(
      ClipboardData(
        text:
            '${vehicle.latitude!.toStringAsFixed(6)}, '
            '${vehicle.longitude!.toStringAsFixed(6)}',
      ),
    );
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Coordinates copied.')));
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
          ?trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vehicle = widget.vehicle;
    // Descriptor-aware provider info (works for registry-added
    // providers too — GpsProvider.fromKey would throw for them).
    final descriptors = ref.watch(providerDescriptorsProvider);
    final descriptor = descriptors.where(
      (d) => d.key == vehicle.providerKey,
    );
    final providerName = descriptor.isEmpty
        ? vehicle.providerKey
        : descriptor.first.displayName;
    final supportsHistory = descriptor.isEmpty
        ? false
        : descriptor.first.supportsHistory;
    final statusColor = AppColors.statusColor(vehicle.status);
    final statusLabel = switch (vehicle.status) {
      VehicleStatus.live => 'LIVE',
      VehicleStatus.idle => 'IDLE',
      VehicleStatus.unknown => 'UNKNOWN',
      VehicleStatus.expired => 'EXPIRED',
    };
    final history = _history;
    final historyPoints = history?.where((v) => v.hasFix).toList() ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(vehicle.displayName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Status hero.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [statusColor, statusColor.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PulsingDot(
                      color: Colors.white,
                      pulsing: vehicle.status == VehicleStatus.live,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      statusLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        vehicle.ignition == null
                            ? 'Ignition unknown'
                            : vehicle.ignition!
                            ? 'Ignition on'
                            : 'Ignition off',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      vehicle.speedKmph == null
                          ? '—'
                          : vehicle.speedKmph!.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'km/h',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  lastUpdatedLabel(vehicle),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Live location preview — tap for the full map.
          if (vehicle.hasFix) ...[
            _LiveLocationMap(vehicle: vehicle),
            const SizedBox(height: 16),
          ],
          // Facts.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Vehicle',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      VehicleCategoryIcon(
                        category: vehicle.category,
                        size: 20,
                        color: theme.colorScheme.primary,
                        tileColor: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ProviderBadge(providerKey: vehicle.providerKey),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    vehicle.category.icon,
                    'Type',
                    vehicle.category.label,
                  ),
                  _infoRow(
                    Icons.business_outlined,
                    'Provider',
                    providerName,
                  ),
                  _infoRow(Icons.tag_outlined, 'Reg no', vehicle.displayName),
                  if (vehicle.imei != null)
                    _infoRow(Icons.memory_outlined, 'IMEI', vehicle.imei!),
                  _infoRow(
                    Icons.location_on_outlined,
                    'Location',
                    vehicle.hasFix
                        ? '${vehicle.latitude!.toStringAsFixed(6)}, '
                              '${vehicle.longitude!.toStringAsFixed(6)}'
                        : 'No fix yet',
                    trailing: vehicle.hasFix
                        ? IconButton(
                            icon: const Icon(Icons.copy_outlined, size: 20),
                            tooltip: 'Copy coordinates',
                            onPressed: _copyCoordinates,
                          )
                        : null,
                  ),
                  _infoRow(
                    Icons.access_time_outlined,
                    'Last update',
                    lastUpdatedLabel(vehicle),
                  ),
                  if (vehicle.lastUpdatedRaw.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 32, top: 2),
                      child: Text(
                        'Provider time: ${vehicle.lastUpdatedRaw}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Today's trip, from the local trip log (recorded on every
          // poll — works for live-snapshot-only providers too).
          const SectionHeader(title: "Today's trip"),
          _TodaysTripSection(vehicle: vehicle),
          const SizedBox(height: 20),
          if (!supportsHistory)
            Card(
              color: AppColors.idle.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.idle,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'History is not supported by '
                        '$providerName — it returns live '
                        'snapshots only.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            const SectionHeader(title: "Today's route"),
            FilledButton.icon(
              onPressed: _loadingHistory ? null : _loadHistory,
              icon: const Icon(Icons.route_outlined),
              label: Text(_loadingHistory ? 'Loading…' : "Load today's route"),
            ),
            if (_historyError != null) ...[
              const SizedBox(height: 12),
              ErrorStateCard(message: _historyError!, onRetry: _loadHistory),
            ],
            if (history != null) ...[
              const SizedBox(height: 12),
              Text(
                '${history.length} point(s) today',
                style: theme.textTheme.titleMedium,
              ),
              if (historyPoints.length >= 2) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(
                          historyPoints.first.latitude!,
                          historyPoints.first.longitude!,
                        ),
                        initialZoom: 12,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.nuvish.unitrack',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: historyPoints
                                  .map((v) => LatLng(v.latitude!, v.longitude!))
                                  .toList(),
                              color: theme.colorScheme.primary,
                              strokeWidth: 5,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              ...history
                  .take(20)
                  .map(
                    (point) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(lastUpdatedLabel(point)),
                        subtitle: Text(
                          '${speedLabel(point)} · '
                          '${point.latitude?.toStringAsFixed(5) ?? '—'}, '
                          '${point.longitude?.toStringAsFixed(5) ?? '—'}',
                        ),
                      ),
                    ),
                  ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Compact "Today's trip" summary from the local trip log: total
/// distance and driving / idling / stopped time for today.
///
/// The log records one point per poll, so this works for
/// live-snapshot-only providers too (Mercy, Pauldea, LiveTrace,
/// HashTrace). The "Today's route" section below adds the server
/// history map where the provider supports it.
class _TodaysTripSection extends ConsumerWidget {
  const _TodaysTripSection({required this.vehicle});

  final Vehicle vehicle;

  Widget _stat(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Watch the log so the section updates as new points arrive.
    ref.watch(tripLogProvider);
    final key = vehicleKey(vehicle.providerKey, vehicle.id);
    final points = ref
        .read(tripLogProvider.notifier)
        .pointsFor(key, day: DateTime.now());
    final summary = computeDaySummary(points, DateTime.now());
    if (summary.points == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.route_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No trip data today yet — positions are recorded '
                  'while the app polls. Check back after a drive.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _stat(
                  context,
                  'Distance',
                  formatDistanceKm(summary.distanceKm),
                  AppColors.live,
                ),
                _stat(
                  context,
                  'Driving',
                  formatDuration(summary.driving),
                  theme.colorScheme.primary,
                ),
                _stat(
                  context,
                  'Idling',
                  formatDuration(summary.idling),
                  AppColors.idle,
                ),
                _stat(
                  context,
                  'Stopped',
                  formatDuration(summary.stopped),
                  AppColors.expired,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${summary.points} point(s) today · Local trip log',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _exportCsv(context, points, summary),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Export today as CSV'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    List<TripPoint> points,
    DaySummary summary,
  ) async {
    final csv = daySummaryCsv(
      vehicleName: vehicle.displayName,
      summary: summary,
      points: points,
    );
    final day = DateTime.now();
    final filename =
        'unitrack-${vehicle.displayName}-${day.year}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}.csv';
    await SharePlus.instance.share(
      ShareParams(text: csv, subject: filename),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report shared — save it from the share sheet.'),
      ),
    );
  }
}
