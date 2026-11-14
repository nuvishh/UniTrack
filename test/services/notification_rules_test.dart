import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/models/vehicle.dart';
import 'package:unitrack/services/alert_rules.dart';

Vehicle _vehicle({
  String id = 'KL01AB1234',
  VehicleStatus status = VehicleStatus.live,
  double? speed,
}) => Vehicle(
  id: id,
  displayName: 'KL01AB1234',
  providerKey: 'aargee',
  status: status,
  speedKmph: speed,
);

void main() {
  group('alertTransitions', () {
    test('ignition on: Idle → Live fires with the current speed', () {
      final alerts = alertTransitions(
        previous: [_vehicle(status: VehicleStatus.idle, speed: 0)],
        current: [_vehicle(status: VehicleStatus.live, speed: 42)],
        settings: const AlertSettings(),
      );
      expect(alerts, hasLength(1));
      expect(alerts.first.kind, AlertKind.ignitionOn);
      expect(alerts.first.speedKmph, 42);
    });

    test('ignition off: Live → Idle fires', () {
      final alerts = alertTransitions(
        previous: [_vehicle(status: VehicleStatus.live, speed: 30)],
        current: [_vehicle(status: VehicleStatus.idle, speed: 0)],
        settings: const AlertSettings(),
      );
      expect(alerts, hasLength(1));
      expect(alerts.first.kind, AlertKind.ignitionOff);
    });

    test('no alert when the status is unchanged', () {
      final alerts = alertTransitions(
        previous: [_vehicle(status: VehicleStatus.live, speed: 30)],
        current: [_vehicle(status: VehicleStatus.live, speed: 35)],
        settings: const AlertSettings(),
      );
      expect(alerts, isEmpty);
    });

    test('a vehicle seen for the first time never alerts', () {
      final alerts = alertTransitions(
        previous: const [],
        current: [_vehicle(status: VehicleStatus.live, speed: 90)],
        settings: const AlertSettings(),
      );
      expect(alerts, isEmpty);
    });

    test('offline: Live → unknown fires; Idle → expired fires', () {
      final alerts = alertTransitions(
        previous: [
          _vehicle(id: 'A', status: VehicleStatus.live),
          _vehicle(id: 'B', status: VehicleStatus.idle),
        ],
        current: [
          _vehicle(id: 'A', status: VehicleStatus.unknown),
          _vehicle(id: 'B', status: VehicleStatus.expired),
        ],
        settings: const AlertSettings(),
      );
      expect(alerts.map((a) => a.kind), everyElement(AlertKind.offline));
      expect(alerts, hasLength(2));
    });

    test('offline: unknown → unknown does not re-alert', () {
      final alerts = alertTransitions(
        previous: [_vehicle(status: VehicleStatus.unknown)],
        current: [_vehicle(status: VehicleStatus.unknown)],
        settings: const AlertSettings(),
      );
      expect(alerts, isEmpty);
    });

    test('overspeed: crossing 80 km/h while live fires once', () {
      final alerts = alertTransitions(
        previous: [_vehicle(status: VehicleStatus.live, speed: 60)],
        current: [_vehicle(status: VehicleStatus.live, speed: 90)],
        settings: const AlertSettings(),
      );
      expect(alerts, hasLength(1));
      expect(alerts.first.kind, AlertKind.overspeed);
      expect(alerts.first.speedKmph, 90);
    });

    test('overspeed: already overspeeding does not re-alert every poll', () {
      final alerts = alertTransitions(
        previous: [_vehicle(status: VehicleStatus.live, speed: 90)],
        current: [_vehicle(status: VehicleStatus.live, speed: 95)],
        settings: const AlertSettings(),
      );
      expect(alerts, isEmpty);
    });

    test('overspeed: fast but idle does not alert', () {
      final alerts = alertTransitions(
        previous: [_vehicle(status: VehicleStatus.idle, speed: 0)],
        current: [_vehicle(status: VehicleStatus.idle, speed: 85)],
        settings: const AlertSettings(),
      );
      expect(alerts, isEmpty);
    });

    test('overspeed: exactly 80 km/h is not overspeeding', () {
      final alerts = alertTransitions(
        previous: [_vehicle(status: VehicleStatus.live, speed: 60)],
        current: [_vehicle(status: VehicleStatus.live, speed: 80)],
        settings: const AlertSettings(),
      );
      expect(alerts, isEmpty);
    });

    test('master off silences every kind', () {
      final alerts = alertTransitions(
        previous: [_vehicle(status: VehicleStatus.idle, speed: 0)],
        current: [_vehicle(status: VehicleStatus.live, speed: 95)],
        settings: const AlertSettings(master: false),
      );
      expect(alerts, isEmpty);
    });

    test('ignition toggle off silences only ignition alerts', () {
      final alerts = alertTransitions(
        previous: [_vehicle(status: VehicleStatus.idle, speed: 0)],
        current: [_vehicle(status: VehicleStatus.live, speed: 95)],
        settings: const AlertSettings(ignition: false),
      );
      expect(alerts.map((a) => a.kind), [AlertKind.overspeed]);
    });

    test('offline toggle off silences only offline alerts', () {
      final alerts = alertTransitions(
        previous: [_vehicle(status: VehicleStatus.live)],
        current: [_vehicle(status: VehicleStatus.unknown)],
        settings: const AlertSettings(offline: false),
      );
      expect(alerts, isEmpty);
    });

    test('vehicles are matched by provider + id, not by position', () {
      final alerts = alertTransitions(
        previous: [
          _vehicle(id: 'A', status: VehicleStatus.live),
          _vehicle(id: 'B', status: VehicleStatus.idle),
        ],
        current: [
          _vehicle(id: 'B', status: VehicleStatus.live),
          _vehicle(id: 'A', status: VehicleStatus.live),
        ],
        settings: const AlertSettings(),
      );
      // Only B changed (idle → live); A stayed live.
      expect(alerts, hasLength(1));
      expect(alerts.first.kind, AlertKind.ignitionOn);
      expect(alerts.first.vehicle.id, 'B');
    });
  });
}
