import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/vehicle.dart';
import '../providers/navigation_provider.dart';
import '../providers/tracker_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/vehicle_category_icon.dart';
import '../widgets/vehicle_status_chip.dart';
import 'add_vehicle_screen.dart';
import 'vehicle_detail_screen.dart';

/// Map view: all vehicles with a fix, on OpenStreetMap tiles
/// (flutter_map — no Google Maps API key needed).
///
/// Markers carry the vehicle's reg no on a status-coloured pin with
/// the vehicle-type icon inside; tapping one opens a bottom sheet
/// with the key facts and a link to details.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();

  static const _fallbackCenter = LatLng(10.8505, 76.2711); // Kerala

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _openDetail(Vehicle vehicle) {
    Navigator.of(context).pop(); // close the bottom sheet first, if open
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicle: vehicle)),
    );
  }

  void _showVehicleSheet(Vehicle vehicle) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vehicle.displayName,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  VehicleStatusChip(status: vehicle.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ProviderBadge(providerKey: vehicle.providerKey),
                  const SizedBox(width: 8),
                  VehicleCategoryIcon(
                    category: vehicle.category,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    vehicle.category.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (vehicle.speedKmph != null) ...[
                    Text(
                      vehicle.speedKmph!.toStringAsFixed(0),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontSize: 36,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'km/h',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    vehicle.ignition == null
                        ? 'Ignition unknown'
                        : vehicle.ignition!
                        ? 'Ignition on'
                        : 'Ignition off',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: vehicle.ignition == null
                          ? theme.colorScheme.onSurfaceVariant
                          : vehicle.ignition!
                          ? AppColors.live
                          : AppColors.idle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(lastUpdatedLabel(vehicle), style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openDetail(vehicle),
                      icon: const Icon(Icons.info_outline),
                      label: const Text('View details'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _fitAll(List<Vehicle> withFix) {
    if (withFix.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vehicles with a location yet.')),
      );
      return;
    }
    if (withFix.length == 1) {
      _mapController.move(
        LatLng(withFix.first.latitude!, withFix.first.longitude!),
        14,
      );
      return;
    }
    final bounds = LatLngBounds.fromPoints(
      withFix.map((v) => LatLng(v.latitude!, v.longitude!)).toList(),
    );
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(56)),
    );
  }

  void _recenter(List<Vehicle> withFix) {
    if (withFix.isEmpty) return;
    final live = withFix.firstWhere(
      (v) => v.status == VehicleStatus.live,
      orElse: () => withFix.first,
    );
    _mapController.move(LatLng(live.latitude!, live.longitude!), 13);
  }

  Future<void> _openAddVehicle() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AddVehicleScreen()));
    await ref.read(trackerProvider.notifier).refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vehicles = ref.watch(trackerProvider.select((s) => s.vehicles));
    // Cross-tab focus: a fleet card's "Map" action asks for a
    // vehicle; centre on it once, then clear the request. If the
    // vehicle is not in the fleet yet, the request stays pending
    // until the next fleet update.
    ref.listen(homeNavProvider.select((s) => s.mapVehicleKey), (_, key) {
      if (key == null) return;
      final match = vehicles.where(
        (v) => '${v.providerKey}:${v.id}' == key,
      );
      if (match.isEmpty || !match.first.hasFix) return;
      _mapController.move(
        LatLng(match.first.latitude!, match.first.longitude!),
        14,
      );
      ref.read(homeNavProvider.notifier).clearMapFocus();
    });
    final withFix = vehicles.where((v) => v.hasFix).toList();
    final center = withFix.isNotEmpty
        ? LatLng(withFix.first.latitude!, withFix.first.longitude!)
        : _fallbackCenter;
    final liveCount = vehicles
        .where((v) => v.status == VehicleStatus.live)
        .length;
    final idleCount = vehicles
        .where((v) => v.status == VehicleStatus.idle)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: withFix.isNotEmpty ? 11 : 6,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.nuvish.unitrack',
              ),
              MarkerLayer(
                markers: withFix.map((vehicle) {
                  return Marker(
                    point: LatLng(vehicle.latitude!, vehicle.longitude!),
                    width: 120,
                    height: 72,
                    child: GestureDetector(
                      onTap: () => _showVehicleSheet(vehicle),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.statusColor(vehicle.status),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              vehicle.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.mono(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.statusColor(vehicle.status),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              vehicle.category.icon,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          // Live count chip: a surfaceContainerHigh pill, as in the
          // prototype. The label truncates instead of overflowing
          // on narrow screens / large system fonts.
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PulsingDot(color: AppColors.live, pulsing: liveCount > 0),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$liveCount live · $idleCount idle · '
                        '${vehicles.length} total',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Fit-all + recenter buttons: tonal, as in the prototype —
          // Fit all is secondaryContainer, Recenter is
          // surfaceContainerHigh with an outline border.
          Positioned(
            right: 16,
            bottom: 24,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'fit_all',
                  onPressed: () => _fitAll(withFix),
                  tooltip: 'Fit all vehicles',
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  foregroundColor: theme.colorScheme.onSecondaryContainer,
                  child: const Icon(Icons.zoom_out_map),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'recenter',
                  onPressed: () => _recenter(withFix),
                  tooltip: 'Centre on a live vehicle',
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  foregroundColor: theme.colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
          if (vehicles.isEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: EmptyState(
                  icon: Icons.map_outlined,
                  title: 'No vehicles on the map yet',
                  message:
                      'Add a vehicle and its live location will '
                      'appear here.',
                  actionLabel: 'Add your first vehicle',
                  onAction: _openAddVehicle,
                ),
              ),
            )
          else if (withFix.isEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_off_outlined),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No locations to show yet — the providers '
                        'have not returned a fix for these vehicles.',
                      ),
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
