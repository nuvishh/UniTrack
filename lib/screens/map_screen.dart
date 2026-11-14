import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/vehicle.dart';
import '../providers/maps_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/tracker_provider.dart';
import '../services/google_maps_key_channel.dart';
import '../services/map_mode.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/osm_attribution.dart';
import '../widgets/vehicle_category_icon.dart';
import '../widgets/vehicle_status_chip.dart';
import 'add_vehicle_screen.dart';
import 'vehicle_detail_screen.dart';

/// Map view: all vehicles with a fix.
///
/// Two map engines (v1.5.0): OpenStreetMap (flutter_map, the
/// default — no key needed) and Google Maps (google_maps_flutter,
/// used only when the user has saved their own API key in Settings).
/// The user can switch between them with the toggle under the count
/// chip whenever a key is saved; without a key the map is always
/// OpenStreetMap.
///
/// Markers carry the vehicle's reg no on a status-coloured pin with
/// the vehicle-type icon inside (OSM) or a status-hued marker with
/// an info window (Google); tapping one opens a bottom sheet with
/// the key facts and a link to details.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  gmaps.GoogleMapController? _googleController;

  /// True once the saved Google Maps key has been applied to the
  /// native SDK in this process (see [GoogleMapsKeyChannel]).
  bool _googleReady = false;
  String? _googleReadyForKey;

  static const _fallbackCenter = LatLng(10.8505, 76.2711); // Kerala

  @override
  void dispose() {
    _mapController.dispose();
    _googleController?.dispose();
    super.dispose();
  }

  /// Applies the saved key to the native SDK, then flips [_googleReady]
  /// so the GoogleMap widget can build. Until then the map tab shows
  /// a loading state instead of a key-less (blank) Google map.
  void _ensureGoogleReady(String key) {
    if (_googleReadyForKey == key) return;
    _googleReadyForKey = key;
    _googleReady = false;
    unawaited(
      GoogleMapsKeyChannel().ensureApplied(key).then((ok) {
        if (!mounted) return;
        setState(() => _googleReady = ok);
      }),
    );
  }

  /// Marker hue matching the app's status colours: live emerald
  /// (~160), idle amber (~38), unknown/expired slate (~213).
  double _googleHue(VehicleStatus status) => switch (status) {
    VehicleStatus.live => 160,
    VehicleStatus.idle => 38,
    VehicleStatus.unknown || VehicleStatus.expired => 213,
  };

  Set<gmaps.Marker> _googleMarkers(List<Vehicle> withFix) {
    final l10n = AppLocalizations.of(context);
    return withFix.map((vehicle) {
      return gmaps.Marker(
        markerId: gmaps.MarkerId('${vehicle.providerKey}:${vehicle.id}'),
        position: gmaps.LatLng(vehicle.latitude!, vehicle.longitude!),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
          _googleHue(vehicle.status),
        ),
        infoWindow: gmaps.InfoWindow(
          title: vehicle.displayName,
          snippet:
              '${l10n.speedLabel(vehicle)} · '
              '${l10n.statusLabel(vehicle.status)}',
          onTap: () => _showVehicleSheet(vehicle),
        ),
        onTap: () => _showVehicleSheet(vehicle),
      );
    }).toSet();
  }

  void _openDetail(Vehicle vehicle) {
    Navigator.of(context).pop(); // close the bottom sheet first, if open
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicle: vehicle)),
    );
  }

  void _showVehicleSheet(Vehicle vehicle) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
                    l10n.categoryLabel(vehicle.category),
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
                        ? l10n.ignitionUnknown
                        : vehicle.ignition!
                        ? l10n.ignitionOnText
                        : l10n.ignitionOffText,
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
              Text(
                l10n.lastUpdatedLabel(vehicle),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openDetail(vehicle),
                      icon: const Icon(Icons.info_outline),
                      label: Text(l10n.viewDetails),
                    ),
                  ),
                  // Share live location (v1.5.0).
                  if (vehicle.hasFix &&
                      vehicle.status != VehicleStatus.expired) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final url = liveLocationUrl(
                          vehicle.latitude!,
                          vehicle.longitude!,
                        );
                        await SharePlus.instance.share(
                          ShareParams(
                            text: l10n.shareLiveLocationText(
                              vehicle.displayName,
                              url,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_location_outlined),
                      label: Text(l10n.shareLiveLocationShort),
                    ),
                  ],
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.close),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _fitAll(List<Vehicle> withFix, MapType mapType) {
    if (mapType == MapType.googleMaps) {
      _fitAllGoogle(withFix);
    } else {
      _fitAllOsm(withFix);
    }
  }

  void _fitAllOsm(List<Vehicle> withFix) {
    if (withFix.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).noVehiclesWithLocation),
        ),
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

  Future<void> _fitAllGoogle(List<Vehicle> withFix) async {
    final controller = _googleController;
    if (withFix.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).noVehiclesWithLocation),
        ),
      );
      return;
    }
    if (controller == null) return;
    if (withFix.length == 1) {
      await controller.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          gmaps.LatLng(withFix.first.latitude!, withFix.first.longitude!),
          14,
        ),
      );
      return;
    }
    try {
      await controller.animateCamera(
        gmaps.CameraUpdate.newLatLngBounds(
          gmaps.LatLngBounds(
            southwest: gmaps.LatLng(
              withFix.map((v) => v.latitude!).reduce((a, b) => a < b ? a : b),
              withFix.map((v) => v.longitude!).reduce((a, b) => a < b ? a : b),
            ),
            northeast: gmaps.LatLng(
              withFix.map((v) => v.latitude!).reduce((a, b) => a > b ? a : b),
              withFix.map((v) => v.longitude!).reduce((a, b) => a > b ? a : b),
            ),
          ),
          56,
        ),
      );
    } catch (_) {
      // newLatLngBounds needs a laid-out map; fall back to the first
      // vehicle if the map has no size yet.
      await controller.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          gmaps.LatLng(withFix.first.latitude!, withFix.first.longitude!),
          11,
        ),
      );
    }
  }

  void _recenter(List<Vehicle> withFix, MapType mapType) {
    if (withFix.isEmpty) return;
    final live = withFix.firstWhere(
      (v) => v.status == VehicleStatus.live,
      orElse: () => withFix.first,
    );
    if (mapType == MapType.googleMaps) {
      unawaited(
        _googleController?.animateCamera(
          gmaps.CameraUpdate.newLatLngZoom(
            gmaps.LatLng(live.latitude!, live.longitude!),
            13,
          ),
        ),
      );
      return;
    }
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
    final l10n = AppLocalizations.of(context);
    final vehicles = ref.watch(trackerProvider.select((s) => s.vehicles));
    // Map engine (v1.5.0): Google Maps only when the user saved their
    // own API key; otherwise OpenStreetMap. The toggle below lets a
    // key holder switch back to OpenStreetMap at any time.
    final googleKey = ref.watch(googleMapsKeyProvider);
    final hasGoogleKey = googleKey != null && googleKey.isNotEmpty;
    final userMapType = ref.watch(mapTypeProvider);
    final mapType = selectMapType(
      hasGoogleMapsKey: hasGoogleKey,
      userChoice: userMapType,
    );
    if (mapType == MapType.googleMaps && hasGoogleKey) {
      _ensureGoogleReady(googleKey);
    }
    // Cross-tab focus: a fleet card's "Map" action asks for a
    // vehicle; centre on it once, then clear the request. If the
    // vehicle is not in the fleet yet, the request stays pending
    // until the next fleet update.
    ref.listen(homeNavProvider.select((s) => s.mapVehicleKey), (_, key) {
      if (key == null) return;
      final match = vehicles.where((v) => '${v.providerKey}:${v.id}' == key);
      if (match.isEmpty || !match.first.hasFix) return;
      if (mapType == MapType.googleMaps) {
        unawaited(
          _googleController?.animateCamera(
            gmaps.CameraUpdate.newLatLngZoom(
              gmaps.LatLng(match.first.latitude!, match.first.longitude!),
              14,
            ),
          ),
        );
      } else {
        _mapController.move(
          LatLng(match.first.latitude!, match.first.longitude!),
          14,
        );
      }
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
    final showGoogleMap = mapType == MapType.googleMaps && _googleReady;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMap)),
      body: Stack(
        children: [
          if (showGoogleMap)
            gmaps.GoogleMap(
              initialCameraPosition: gmaps.CameraPosition(
                target: gmaps.LatLng(center.latitude, center.longitude),
                zoom: withFix.isNotEmpty ? 11 : 6,
              ),
              markers: _googleMarkers(withFix),
              onMapCreated: (controller) => _googleController = controller,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            )
          else if (mapType == MapType.googleMaps)
            // Key saved but not yet applied to the native SDK: brief
            // loading state instead of a key-less (blank) Google map.
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(l10n.loadingGoogleMap),
                ],
              ),
            )
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: withFix.isNotEmpty ? 11 : 6,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                // ODbL attribution (v1.5.0) — required on every
                // OpenStreetMap view. Google Maps draws its own.
                const OsmAttribution(),
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
                        l10n.mapCountLabel(
                          liveCount,
                          idleCount,
                          vehicles.length,
                        ),
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
          // Map-type toggle (v1.5.0): only when a Google Maps key is
          // saved. Lets the user switch back to OpenStreetMap at any
          // time — e.g. when Google Maps shows an error for a bad key.
          if (hasGoogleKey)
            Positioned(
              top: 68,
              left: 16,
              right: 16,
              child: Center(
                child: SegmentedButton<MapType>(
                  segments: [
                    ButtonSegment(
                      value: MapType.openStreetMap,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: Text(l10n.mapTypeOsm),
                    ),
                    ButtonSegment(
                      value: MapType.googleMaps,
                      icon: const Icon(Icons.map, size: 18),
                      label: Text(l10n.mapTypeGoogle),
                    ),
                  ],
                  selected: {mapType},
                  onSelectionChanged: (selected) {
                    ref
                        .read(mapTypeProvider.notifier)
                        .setMapType(selected.first);
                  },
                  style: SegmentedButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHigh,
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
                  onPressed: () => _fitAll(withFix, mapType),
                  tooltip: l10n.fitAllVehicles,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  foregroundColor: theme.colorScheme.onSecondaryContainer,
                  child: const Icon(Icons.zoom_out_map),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'recenter',
                  onPressed: () => _recenter(withFix, mapType),
                  tooltip: l10n.centreOnLive,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  foregroundColor: theme.colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
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
                  title: l10n.mapEmptyTitle2,
                  message: l10n.mapEmptyMessage2,
                  actionLabel: l10n.emptyFleetAction,
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
                child: Row(
                  children: [
                    const Icon(Icons.location_off_outlined),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l10n.noLocationsYet)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
