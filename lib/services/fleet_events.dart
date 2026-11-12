import '../models/alert.dart';
import '../models/geofence.dart';
import '../models/trip_point.dart';
import '../models/vehicle.dart';
import '../utils/geo.dart';

/// Detects fleet events by comparing a vehicle's previous poll
/// snapshot with the new one. Pure function — no I/O — so it is
/// unit-tested directly (see test/fleet_events_test.dart).
///
/// - Ignition On/Off: the ignition flag changed between polls.
/// - Overspeed: speed crossed above the threshold (one alert per
///   crossing, not one per poll while still speeding).
/// - Geofence enter/exit: the vehicle crossed a geofence boundary.
///   [insideByGeofenceId] is updated in place: a geofence seen for
///   the first time records its state silently (no alert), so adding
///   a geofence never fires a false crossing.
///
/// Pass `previous: null` on the first sighting of a vehicle: no
/// ignition or overspeed alert fires, and geofence states initialise
/// silently.
class FleetEventDetector {
  static List<FleetAlert> detect({
    required Vehicle? previous,
    required Vehicle next,
    required double overspeedThresholdKmh,
    List<Geofence> geofences = const [],
    Map<String, bool>? insideByGeofenceId,
  }) {
    final alerts = <FleetAlert>[];
    // Geofence state lives in the caller's map when one is passed;
    // without it, crossings are evaluated against a fresh (empty)
    // map, so only ignition/overspeed fire.
    final insideState = insideByGeofenceId ?? <String, bool>{};
    final key = vehicleKey(next.providerKey, next.id);
    final now = DateTime.now();
    String idFor(AlertType type) =>
        '${now.millisecondsSinceEpoch}-${type.name}-$key';

    // Ignition transitions need a previous snapshot to compare with.
    if (previous != null &&
        previous.ignition != null &&
        next.ignition != null &&
        previous.ignition != next.ignition) {
      final on = next.ignition!;
      alerts.add(
        FleetAlert(
          id: idFor(on ? AlertType.ignitionOn : AlertType.ignitionOff),
          type: on ? AlertType.ignitionOn : AlertType.ignitionOff,
          severity: AlertSeverity.low,
          vehicleKey: key,
          vehicleName: next.displayName,
          time: now,
          latitude: next.latitude,
          longitude: next.longitude,
        ),
      );
    }

    // Overspeed: alert once per upward crossing of the threshold.
    final speed = next.speedKmph;
    final prevSpeed = previous?.speedKmph;
    if (speed != null &&
        speed > overspeedThresholdKmh &&
        (prevSpeed == null || prevSpeed <= overspeedThresholdKmh)) {
      alerts.add(
        FleetAlert(
          id: idFor(AlertType.overspeed),
          type: AlertType.overspeed,
          severity: speed >= overspeedThresholdKmh + 20
              ? AlertSeverity.high
              : AlertSeverity.medium,
          vehicleKey: key,
          vehicleName: next.displayName,
          time: now,
          latitude: next.latitude,
          longitude: next.longitude,
          message:
              'Speed ${speed.toStringAsFixed(0)} km/h — '
              'limit ${overspeedThresholdKmh.toStringAsFixed(0)} km/h',
          speedKmph: speed,
        ),
      );
    }

    // Geofence crossings, only when the vehicle has a fix.
    if (next.hasFix) {
      for (final fence in geofences) {
        final inside = isWithinRadiusM(
          next.latitude!,
          next.longitude!,
          fence.latitude,
          fence.longitude,
          fence.radiusM,
        );
        final wasInside = insideState[fence.id];
        if (wasInside == null) {
          // First sighting: record the state, fire nothing.
          insideState[fence.id] = inside;
        } else if (wasInside != inside) {
          insideState[fence.id] = inside;
          alerts.add(
            FleetAlert(
              id: idFor(
                inside ? AlertType.geofenceEnter : AlertType.geofenceExit,
              ),
              type: inside
                  ? AlertType.geofenceEnter
                  : AlertType.geofenceExit,
              severity: AlertSeverity.medium,
              vehicleKey: key,
              vehicleName: next.displayName,
              time: now,
              latitude: next.latitude,
              longitude: next.longitude,
              message:
                  '${inside ? 'Entered' : 'Left'} ${fence.name} '
                  '(${fence.radiusLabel})',
              geofenceName: fence.name,
            ),
          );
        }
      }
    }
    return alerts;
  }
}
