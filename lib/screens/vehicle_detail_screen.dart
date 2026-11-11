import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/gps_provider.dart';
import '../models/vehicle.dart';
import '../providers/tracker_provider.dart';
import '../services/providers/gps_provider_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/vehicle_status_chip.dart';

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

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen> {
  List<Vehicle>? _history;
  String? _historyError;
  bool _loadingHistory = false;

  GpsProvider get _provider => GpsProvider.fromKey(widget.vehicle.providerKey);

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
              borderRadius: BorderRadius.circular(20),
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
                      ProviderBadge(providerKey: vehicle.providerKey),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.business_outlined,
                    'Provider',
                    _provider.displayName,
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
          if (!_provider.supportsHistory)
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
                        '${_provider.displayName} — it returns live '
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
