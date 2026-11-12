import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../models/trip_point.dart';
import '../models/vehicle.dart';
import '../providers/navigation_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/trip_log_provider.dart';
import '../services/providers/gps_provider_client.dart';
import '../services/trip_summary.dart';
import '../theme/app_theme.dart';
import '../utils/geo.dart';
import '../utils/time_format.dart';
import '../widgets/app_widgets.dart';

/// Reports (Volty-style): per-vehicle day summary — total distance,
/// driving / idling / stopped time — with the day's route on a map
/// and a CSV export.
///
/// Data: the local trip log (recorded on every poll, so it works for
/// live-snapshot-only providers too). When the provider supports
/// server history, that history is fetched once per selection and
/// merged with the local log. Today/Yesterday tabs only — older days
/// come from the 7-day log through the same day picker in a later
/// version.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  Vehicle? _vehicle;
  String _day = 'today';
  List<TripPoint> _points = const [];
  DaySummary? _summary;
  String _source = '';
  bool _loading = false;
  String? _notice;
  bool _didInitFocus = false;

  DateTime get _selectedDay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _day == 'yesterday'
        ? today.subtract(const Duration(days: 1))
        : today;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyFocus());
  }

  void _applyFocus() {
    if (_didInitFocus) return;
    _didInitFocus = true;
    final focus = ref.read(homeNavProvider).reportsVehicleKey;
    if (focus != null) {
      final vehicles = ref.read(trackerProvider).vehicles;
      final match = vehicles.where(
        (v) => '${v.providerKey}:${v.id}' == focus,
      );
      if (match.isNotEmpty) {
        setState(() => _vehicle = match.first);
      }
      ref.read(homeNavProvider.notifier).clearReportsFocus();
    }
    _load();
  }

  Future<void> _load() async {
    final vehicle = _vehicle;
    if (vehicle == null) return;
    setState(() {
      _loading = true;
      _notice = null;
    });
    final day = _selectedDay;
    // Local log first — always available.
    final local = ref
        .read(tripLogProvider.notifier)
        .pointsFor('${vehicle.providerKey}:${vehicle.id}', day: day);
    var points = List<TripPoint>.from(local);
    var source = 'Local trip log';
    var notice = local.isEmpty
        ? 'No trip data for this day yet — positions are recorded '
              'while the app polls. Keep polling on and check back '
              'after a drive.'
        : null;
    // Merge server history where the provider supports it. Fetched
    // once per selection (history calls are rate-limited per day).
    try {
      final history = await ref
          .read(trackerProvider.notifier)
          .fetchHistoryFor(vehicle, from: day, to: day.add(const Duration(days: 1)));
      final historyPoints = history
          .where((v) => v.hasFix && v.lastUpdated != null)
          .map(
            (v) => TripPoint(
              time: v.lastUpdated!,
              latitude: v.latitude!,
              longitude: v.longitude!,
              speedKmph: v.speedKmph,
              ignition: v.ignition,
            ),
          )
          .toList();
      if (historyPoints.isNotEmpty) {
        points = _merge(points, historyPoints);
        source = 'Provider history + local log';
        notice = null;
      }
    } on UnsupportedError {
      // Live-snapshot-only provider — the local log is the report.
    } on ProviderException catch (e) {
      notice = 'Provider history unavailable (${e.message}) — '
          'showing the local log.';
    } catch (_) {
      notice = 'Provider history unavailable — showing the local log.';
    }
    if (!mounted) return;
    setState(() {
      _points = points
        ..sort((a, b) => a.time.compareTo(b.time));
      _summary = computeDaySummary(_points, day);
      _source = source;
      _notice = notice;
      _loading = false;
    });
  }

  /// Merges two point lists, de-duplicating by minute + rounded
  /// position, so a point from both sources counts once.
  List<TripPoint> _merge(List<TripPoint> a, List<TripPoint> b) {
    final seen = <String>{};
    final merged = <TripPoint>[];
    for (final point in [...a, ...b]) {
      final key =
          '${point.time.millisecondsSinceEpoch ~/ 60000}:'
          '${point.latitude.toStringAsFixed(4)}:'
          '${point.longitude.toStringAsFixed(4)}';
      if (seen.add(key)) merged.add(point);
    }
    return merged;
  }

  Future<void> _export() async {
    final vehicle = _vehicle;
    final summary = _summary;
    if (vehicle == null || summary == null) return;
    final csv = daySummaryCsv(
      vehicleName: vehicle.displayName,
      summary: summary,
      points: _points,
    );
    final day = _selectedDay;
    final filename =
        'unitrack-${vehicle.displayName}-${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}.csv';
    await SharePlus.instance.share(
      ShareParams(text: csv, subject: filename),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report shared — save it from the share sheet.')),
    );
  }

  void _selectVehicle(Vehicle? vehicle) {
    if (vehicle == _vehicle) return;
    setState(() => _vehicle = vehicle);
    _load();
  }

  void _selectDay(String day) {
    if (day == _day) return;
    setState(() => _day = day);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vehicles = ref.watch(
      trackerProvider.select((s) => s.vehicles),
    );
    // Default to the first vehicle once the fleet loads.
    if (_vehicle == null && vehicles.isNotEmpty) {
      _vehicle ??= vehicles.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _summary == null && !_loading) _load();
      });
    }
    final summary = _summary;
    final points = _points;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload report',
            onPressed: _vehicle == null || _loading ? null : _load,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Export as CSV',
            onPressed: summary == null || summary.points == 0
                ? null
                : _export,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (vehicles.isEmpty)
            const EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No vehicles yet',
              message: 'Add a vehicle and its day reports will appear here.',
            )
          else ...[
            _buildVehiclePicker(theme, vehicles),
            const SizedBox(height: 12),
          ],
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'today', label: Text('Today')),
              ButtonSegment(
                value: 'yesterday',
                label: Text('Yesterday'),
              ),
            ],
            selected: {_day},
            onSelectionChanged: (selected) => _selectDay(selected.first),
          ),
          const SizedBox(height: 16),
          if (vehicles.isNotEmpty) ...[
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (summary != null) ...[
              _SummaryGrid(summary: summary),
              const SizedBox(height: 16),
              _RouteMap(points: points),
              const SizedBox(height: 12),
              Text(
                '$_source · ${summary.points} point(s) · '
                '${dayLabel(_selectedDay)}',
                style: theme.textTheme.bodySmall,
              ),
              if (_notice != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: AppColors.idle.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.idle,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _notice!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildVehiclePicker(ThemeData theme, List<Vehicle> vehicles) {
    return DropdownButtonFormField<Vehicle>(
      initialValue: _vehicle != null && vehicles.contains(_vehicle)
          ? _vehicle
          : null,
      decoration: const InputDecoration(
        labelText: 'Vehicle',
        prefixIcon: Icon(Icons.directions_bus_outlined),
      ),
      items: vehicles
          .map(
            (v) => DropdownMenuItem(value: v, child: Text(v.displayName)),
          )
          .toList(),
      onChanged: _selectVehicle,
    );
  }
}

/// Two-by-two summary cards, Volty-style: a coloured top bar, a
/// small label, and one big number each.
class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final DaySummary summary;

  Widget _card(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 5, color: color),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label, style: theme.textTheme.bodyMedium),
                    ),
                    Icon(icon, size: 20, color: color),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontSize: 30,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Narrow phones keep two columns (cards are compact); the
        // values ellipsize instead of overflowing.
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _card(
                    context,
                    'Total Distance',
                    formatDistanceKm(summary.distanceKm),
                    Icons.trending_up,
                    AppColors.live,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _card(
                    context,
                    'Driving Time',
                    formatDuration(summary.driving),
                    Icons.schedule_outlined,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _card(
                    context,
                    'Idling Time',
                    formatDuration(summary.idling),
                    Icons.pause_circle_outline,
                    AppColors.idle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _card(
                    context,
                    'Stopped Time',
                    formatDuration(summary.stopped),
                    Icons.stop_circle_outlined,
                    AppColors.expired,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The day's route on OpenStreetMap: a polyline through the points,
/// a numbered start pin and the last position.
class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.points});

  final List<TripPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.route_outlined),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('No route to show yet for this day.'),
              ),
            ],
          ),
        ),
      );
    }
    final latLngs = points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 260,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: latLngs.first,
            initialZoom: 12,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.nuvish.unitrack',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: latLngs,
                  color: theme.colorScheme.primary,
                  strokeWidth: 5,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: latLngs.first,
                  width: 36,
                  height: 36,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.expired,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '1',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                Marker(
                  point: latLngs.last,
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.location_on,
                    color: AppColors.live,
                    size: 40,
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
