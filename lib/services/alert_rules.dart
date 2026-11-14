import '../models/vehicle.dart';

/// Which vehicle-alert transitions fire a local notification.
///
/// All on by default. The master switch gates everything; the other
/// three gate one alert kind each.
class AlertSettings {
  const AlertSettings({
    this.master = true,
    this.ignition = true,
    this.overspeed = true,
    this.offline = true,
  });

  final bool master;
  final bool ignition;
  final bool overspeed;
  final bool offline;

  AlertSettings copyWith({
    bool? master,
    bool? ignition,
    bool? overspeed,
    bool? offline,
  }) {
    return AlertSettings(
      master: master ?? this.master,
      ignition: ignition ?? this.ignition,
      overspeed: overspeed ?? this.overspeed,
      offline: offline ?? this.offline,
    );
  }
}

/// One alert-worthy transition for one vehicle.
enum AlertKind {
  /// Idle → Live.
  ignitionOn,

  /// Live → Idle.
  ignitionOff,

  /// Live/Idle → Offline (unknown/expired).
  offline,

  /// Speed crossed above 80 km/h while live.
  overspeed,
}

/// A notification to show for a vehicle.
class VehicleAlert {
  const VehicleAlert({
    required this.kind,
    required this.vehicle,
    this.speedKmph,
  });

  final AlertKind kind;
  final Vehicle vehicle;

  /// Speed at the moment of the alert (ignition-on / overspeed).
  final double? speedKmph;
}

/// Speed above which a live vehicle counts as overspeeding.
const double overspeedThresholdKmph = 80;

/// Pure transition check: which alerts does one poll's change
/// deserve?
///
/// Compares each vehicle's new state with its previous one.
/// - Ignition on: Idle → Live. Ignition off: Live → Idle.
/// - Offline: Live/Idle → unknown/expired, after previously
///   live/idle.
/// - Overspeed: speed crossed above 80 km/h while live. A vehicle
///   that was ALREADY overspeeding does not re-alert on every poll.
/// - A vehicle seen for the first time (no previous snapshot) never
///   alerts — appearing in the fleet is not a transition.
///
/// No I/O, no context — unit-tested in test/notification_rules_test.dart.
List<VehicleAlert> alertTransitions({
  required List<Vehicle> previous,
  required List<Vehicle> current,
  required AlertSettings settings,
}) {
  if (!settings.master) return const [];

  final prevByKey = <String, Vehicle>{
    for (final v in previous) '${v.providerKey}:${v.id}': v,
  };

  final alerts = <VehicleAlert>[];
  for (final vehicle in current) {
    final prev = prevByKey['${vehicle.providerKey}:${vehicle.id}'];
    if (prev == null) continue;

    if (settings.ignition) {
      if (prev.status == VehicleStatus.idle &&
          vehicle.status == VehicleStatus.live) {
        alerts.add(
          VehicleAlert(
            kind: AlertKind.ignitionOn,
            vehicle: vehicle,
            speedKmph: vehicle.speedKmph,
          ),
        );
      } else if (prev.status == VehicleStatus.live &&
          vehicle.status == VehicleStatus.idle) {
        alerts.add(VehicleAlert(kind: AlertKind.ignitionOff, vehicle: vehicle));
      }
    }

    if (settings.offline) {
      final wasReachable =
          prev.status == VehicleStatus.live ||
          prev.status == VehicleStatus.idle;
      final nowOffline =
          vehicle.status == VehicleStatus.unknown ||
          vehicle.status == VehicleStatus.expired;
      if (wasReachable && nowOffline) {
        alerts.add(VehicleAlert(kind: AlertKind.offline, vehicle: vehicle));
      }
    }

    if (settings.overspeed) {
      final wasOverspeed = (prev.speedKmph ?? 0) > overspeedThresholdKmph;
      final isOverspeed =
          vehicle.status == VehicleStatus.live &&
          (vehicle.speedKmph ?? 0) > overspeedThresholdKmph;
      if (isOverspeed && !wasOverspeed) {
        alerts.add(
          VehicleAlert(
            kind: AlertKind.overspeed,
            vehicle: vehicle,
            speedKmph: vehicle.speedKmph,
          ),
        );
      }
    }
  }
  return alerts;
}
