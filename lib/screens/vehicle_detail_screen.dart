import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/trip_point.dart';
import '../models/vehicle.dart';
import '../providers/registry_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/trip_log_provider.dart';
import '../services/map_mode.dart';
import '../services/providers/gps_provider_client.dart';
import '../services/trip_playback.dart';
import '../services/trip_summary.dart';
import '../theme/app_theme.dart';
import '../utils/geo.dart';
import '../widgets/app_widgets.dart';
import '../widgets/osm_attribution.dart';
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
    final l10n = AppLocalizations.of(context);
    final point = LatLng(vehicle.latitude!, vehicle.longitude!);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const MapScreen())),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 200,
              child: IgnorePointer(
                child: FlutterMap(
                  options: MapOptions(initialCenter: point, initialZoom: 14),
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
                    // ODbL attribution (v1.5.0).
                    const OsmAttribution(),
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
                      l10n.liveLocationHint,
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

  /// Trip playback (v1.5.0): replays the loaded history on the route
  /// map. The [TripPlayback] object holds the position and the math;
  /// this timer steps it.
  TripPlayback? _playback;
  Timer? _playbackTimer;
  bool _playing = false;
  double _playbackSpeed = 1.0;

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _resetPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _playing = false;
    _playback = null;
  }

  void _startPlayback(List<Vehicle> points) {
    _playbackTimer?.cancel();
    _playback ??= TripPlayback(points: points);
    _playback!.speedMultiplier = _playbackSpeed;
    setState(() => _playing = true);
    _playbackTimer = Timer.periodic(_playback!.stepDuration, (_) {
      if (!mounted) return;
      final playback = _playback;
      if (playback == null) return;
      if (playback.isAtEnd) {
        _pausePlayback();
        return;
      }
      setState(playback.advance);
    });
  }

  void _pausePlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    if (mounted) setState(() => _playing = false);
  }

  void _setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    final playback = _playback;
    if (playback != null) playback.speedMultiplier = speed;
    // A running timer restarts at the new pace.
    if (_playing && playback != null) {
      _playbackTimer?.cancel();
      _playbackTimer = Timer.periodic(playback.stepDuration, (_) {
        if (!mounted) return;
        if (playback.isAtEnd) {
          _pausePlayback();
          return;
        }
        setState(playback.advance);
      });
    } else {
      setState(() {});
    }
  }

  /// Shares a Google Maps link to the vehicle's live location.
  Future<void> _shareLiveLocation() async {
    final vehicle = widget.vehicle;
    if (!vehicle.hasFix) return;
    final url = liveLocationUrl(vehicle.latitude!, vehicle.longitude!);
    await SharePlus.instance.share(
      ShareParams(
        text: AppLocalizations.of(
          context,
        ).shareLiveLocationText(vehicle.displayName, url),
      ),
    );
  }

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
      _resetPlayback();
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
      setState(
        () =>
            _historyError = AppLocalizations.of(context).historyLoadError('$e'),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).coordinatesCopied)),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
    bool monoValue = false,
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
            child: Text(
              value,
              style: monoValue
                  ? AppTheme.mono(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    )
                  : Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final vehicle = widget.vehicle;
    // Descriptor-aware provider info (works for registry-added
    // providers too — GpsProvider.fromKey would throw for them).
    final descriptors = ref.watch(providerDescriptorsProvider);
    final descriptor = descriptors.where((d) => d.key == vehicle.providerKey);
    final providerName = descriptor.isEmpty
        ? vehicle.providerKey
        : descriptor.first.displayName;
    final supportsHistory = descriptor.isEmpty
        ? false
        : descriptor.first.supportsHistory;
    final history = _history;
    final historyPoints = history?.where((v) => v.hasFix).toList() ?? const [];
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainer,
              foregroundColor: theme.colorScheme.onSurface,
            ),
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.backToFleet,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          vehicle.displayName,
          style: AppTheme.mono(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Status hero: a tonal primaryContainer card (Material You,
          // v1.3.0 — the old status-colour gradient is gone), with
          // the status chip, big speed and ignition, as in the
          // prototype's detail hero.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    VehicleStatusChip(status: vehicle.status),
                    const Spacer(),
                    Text(
                      l10n.lastUpdatedLabel(vehicle),
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.8,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'km/h',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l10n.ignition,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.75),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          vehicle.ignition == null
                              ? l10n.unknown
                              : vehicle.ignition!
                              ? l10n.ignitionOnRunning
                              : l10n.ignitionOffParked,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Live location preview — tap for the full map.
          if (vehicle.hasFix) ...[
            _LiveLocationMap(vehicle: vehicle),
            const SizedBox(height: 12),
            // Share live location (v1.5.0): a Google Maps link to the
            // current fix. Only when there is a real, live fix.
            if (vehicle.status != VehicleStatus.expired)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _shareLiveLocation,
                  icon: const Icon(Icons.share_location_outlined),
                  label: Text(l10n.shareLiveLocation),
                ),
              ),
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
                          l10n.vehicleSection,
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
                    l10n.typeLabel,
                    l10n.categoryLabel(vehicle.category),
                  ),
                  _infoRow(
                    Icons.business_outlined,
                    l10n.providerLabel,
                    providerName,
                  ),
                  _infoRow(
                    Icons.tag_outlined,
                    l10n.regNoLabel2,
                    vehicle.displayName,
                    monoValue: true,
                  ),
                  if (vehicle.imei != null)
                    _infoRow(
                      Icons.memory_outlined,
                      'IMEI',
                      vehicle.imei!,
                      monoValue: true,
                    ),
                  _infoRow(
                    Icons.location_on_outlined,
                    l10n.locationLabel,
                    vehicle.hasFix
                        ? '${vehicle.latitude!.toStringAsFixed(6)}, '
                              '${vehicle.longitude!.toStringAsFixed(6)}'
                        : l10n.noFixYet,
                    trailing: vehicle.hasFix
                        ? IconButton(
                            icon: const Icon(Icons.copy_outlined, size: 20),
                            tooltip: l10n.copyCoordinates,
                            onPressed: _copyCoordinates,
                          )
                        : null,
                  ),
                  _infoRow(
                    Icons.access_time_outlined,
                    l10n.lastUpdated,
                    l10n.lastUpdatedLabel(vehicle),
                  ),
                  if (vehicle.lastUpdatedRaw.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 32, top: 2),
                      child: Text(
                        l10n.providerTime(vehicle.lastUpdatedRaw),
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
          SectionHeader(title: l10n.todaysTrip),
          _TodaysTripSection(vehicle: vehicle),
          const SizedBox(height: 20),
          if (!supportsHistory)
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.onTertiaryContainer,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.historyNotSupported(providerName),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.tripPlaybackNotAvailable,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SectionHeader(title: l10n.todaysRoute),
            FilledButton.icon(
              onPressed: _loadingHistory ? null : _loadHistory,
              icon: const Icon(Icons.route_outlined),
              label: Text(
                _loadingHistory ? l10n.loading : l10n.loadTodaysRoute,
              ),
            ),
            if (_historyError != null) ...[
              const SizedBox(height: 12),
              ErrorStateCard(message: _historyError!, onRetry: _loadHistory),
            ],
            if (history != null) ...[
              const SizedBox(height: 12),
              Text(
                l10n.pointsToday(history.length),
                style: theme.textTheme.titleMedium,
              ),
              if (historyPoints.length >= 2) ...[
                const SizedBox(height: 8),
                _TripPlaybackMap(
                  points: historyPoints,
                  playback: _playback,
                ),
                const SizedBox(height: 12),
                _TripPlaybackControls(
                  points: historyPoints,
                  playback: _playback,
                  playing: _playing,
                  speed: _playbackSpeed,
                  onPlay: () => _startPlayback(historyPoints),
                  onPause: _pausePlayback,
                  onSeek: (index) {
                    _playback ??= TripPlayback(points: historyPoints);
                    setState(() => _playback!.seek(index));
                  },
                  onSpeed: _setPlaybackSpeed,
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
                        title: Text(l10n.lastUpdatedLabel(point)),
                        subtitle: Text(
                          '${l10n.speedLabel(point)} · '
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

  Widget _stat(BuildContext context, String label, String value, Color color) {
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
    final l10n = AppLocalizations.of(context);
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
                child: Text(l10n.noTripData, style: theme.textTheme.bodyMedium),
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
                  l10n.distance,
                  formatDistanceKm(summary.distanceKm),
                  AppColors.live,
                ),
                _stat(
                  context,
                  l10n.drivingTime,
                  formatDuration(summary.driving),
                  theme.colorScheme.primary,
                ),
                _stat(
                  context,
                  l10n.idling,
                  formatDuration(summary.idling),
                  AppColors.idle,
                ),
                _stat(
                  context,
                  l10n.stopped,
                  formatDuration(summary.stopped),
                  AppColors.expired,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.pointsTodayLog(summary.points),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _exportCsv(context, points, summary),
                icon: const Icon(Icons.share_outlined),
                label: Text(l10n.exportCsv),
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
    await SharePlus.instance.share(ShareParams(text: csv, subject: filename));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).reportShared)),
    );
  }
}

/// Today's route map with trip playback (v1.5.0).
///
/// Before playback starts the whole route is drawn in the primary
/// colour. Once playback runs, the travelled part stays primary and
/// the remaining part fades, with a marker on the current point.
class _TripPlaybackMap extends StatelessWidget {
  const _TripPlaybackMap({required this.points, required this.playback});

  final List<Vehicle> points;
  final TripPlayback? playback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = playback?.current;
    final travelled = playback == null
        ? points
        : playback!.travelled;
    final remaining = playback == null
        ? const <Vehicle>[]
        : playback!.remaining;
    return SizedBox(
      height: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(
              points.first.latitude!,
              points.first.longitude!,
            ),
            initialZoom: 12,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.nuvish.unitrack',
            ),
            PolylineLayer(
              polylines: [
                if (travelled.length >= 2)
                  Polyline(
                    points: travelled
                        .map((v) => LatLng(v.latitude!, v.longitude!))
                        .toList(),
                    color: theme.colorScheme.primary,
                    strokeWidth: 5,
                  ),
                if (remaining.length >= 2)
                  Polyline(
                    points: remaining
                        .map((v) => LatLng(v.latitude!, v.longitude!))
                        .toList(),
                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                    strokeWidth: 5,
                  ),
              ],
            ),
            if (current != null && current.hasFix)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(current.latitude!, current.longitude!),
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.location_on,
                      color: theme.colorScheme.primary,
                      size: 40,
                    ),
                  ),
                ],
              ),
            // ODbL attribution (v1.5.0).
            const OsmAttribution(),
          ],
        ),
      ),
    );
  }
}

/// Play / pause, scrub slider, current time + speed, and 1x/2x/4x
/// speed control for trip playback (v1.5.0).
class _TripPlaybackControls extends StatelessWidget {
  const _TripPlaybackControls({
    required this.points,
    required this.playback,
    required this.playing,
    required this.speed,
    required this.onPlay,
    required this.onPause,
    required this.onSeek,
    required this.onSpeed,
  });

  final List<Vehicle> points;
  final TripPlayback? playback;
  final bool playing;
  final double speed;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final ValueChanged<int> onSeek;
  final ValueChanged<double> onSpeed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final index = playback?.index ?? 0;
    final current = playback?.current;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton.filled(
                  onPressed: playing ? onPause : onPlay,
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  tooltip: playing ? l10n.pauseTrip : l10n.playTrip,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tripPlayback,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        l10n.playbackPoint(index + 1, points.length),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (current != null)
                  Text(
                    l10n.speedLabel(current),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            Slider(
              value: index.toDouble(),
              max: (points.length - 1).toDouble(),
              divisions: points.length - 1,
              label: l10n.playbackPoint(index + 1, points.length),
              onChanged: (value) => onSeek(value.round()),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    current == null
                        ? ''
                        : l10n.lastUpdatedLabel(current),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                SegmentedButton<double>(
                  segments: TripPlayback.speeds
                      .map(
                        (s) => ButtonSegment(
                          value: s,
                          label: Text('${s.toStringAsFixed(0)}x'),
                        ),
                      )
                      .toList(),
                  selected: {speed},
                  onSelectionChanged: (selected) =>
                      onSpeed(selected.first),
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
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
