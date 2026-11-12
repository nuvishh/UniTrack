import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/models/alert.dart';
import 'package:unitrack/models/geofence.dart';
import 'package:unitrack/models/vehicle.dart';
import 'package:unitrack/services/fleet_events.dart';

// All values below are FAKE examples — never real reg numbers, IMEIs,
// vehicle ids or keys.
Vehicle _vehicle({
  double speed = 0,
  bool? ignition,
  double lat = 12.0,
  double lon = 75.0,
  DateTime? time,
}) {
  return Vehicle(
    id: 'KL00XX0000',
    displayName: 'KL00XX0000',
    providerKey: 'aargee',
    latitude: lat,
    longitude: lon,
    speedKmph: speed,
    ignition: ignition,
    lastUpdated: time ?? DateTime(2026, 11, 12, 9, 0),
    status: VehicleStatus.live,
  );
}

void main() {
  group('FleetEventDetector.detect — ignition', () {
    test('first sighting records no alert', () {
      final events = FleetEventDetector.detect(
        previous: null,
        next: _vehicle(ignition: true),
        overspeedThresholdKmh: 80,
      );
      expect(events, isEmpty);
    });

    test('ignition off → on fires an Ignition On alert', () {
      final events = FleetEventDetector.detect(
        previous: _vehicle(ignition: false),
        next: _vehicle(ignition: true),
        overspeedThresholdKmh: 80,
      );
      expect(events, hasLength(1));
      expect(events.first.type, AlertType.ignitionOn);
      expect(events.first.title, 'Ignition On - KL00XX0000');
      expect(events.first.severity, AlertSeverity.low);
    });

    test('ignition on → off fires an Ignition Off alert', () {
      final events = FleetEventDetector.detect(
        previous: _vehicle(ignition: true),
        next: _vehicle(ignition: false),
        overspeedThresholdKmh: 80,
      );
      expect(events, hasLength(1));
      expect(events.first.type, AlertType.ignitionOff);
      expect(events.first.title, 'Ignition Off - KL00XX0000');
    });

    test('no change fires nothing', () {
      final events = FleetEventDetector.detect(
        previous: _vehicle(ignition: true),
        next: _vehicle(ignition: true),
        overspeedThresholdKmh: 80,
      );
      expect(events, isEmpty);
    });

    test('unknown ignition never fires', () {
      final events = FleetEventDetector.detect(
        previous: _vehicle(ignition: true),
        next: _vehicle(ignition: null),
        overspeedThresholdKmh: 80,
      );
      expect(events, isEmpty);
    });
  });

  group('FleetEventDetector.detect — overspeed', () {
    test('crossing above the threshold fires once', () {
      final events = FleetEventDetector.detect(
        previous: _vehicle(speed: 60, ignition: true),
        next: _vehicle(speed: 95, ignition: true),
        overspeedThresholdKmh: 80,
      );
      expect(events, hasLength(1));
      expect(events.first.type, AlertType.overspeed);
      expect(events.first.severity, AlertSeverity.medium);
      expect(events.first.message, contains('95 km/h'));
    });

    test('staying above the threshold does not re-fire', () {
      final events = FleetEventDetector.detect(
        previous: _vehicle(speed: 95, ignition: true),
        next: _vehicle(speed: 97, ignition: true),
        overspeedThresholdKmh: 80,
      );
      expect(events, isEmpty);
    });

    test('dropping back below, then crossing again, fires again', () {
      final first = FleetEventDetector.detect(
        previous: _vehicle(speed: 95, ignition: true),
        next: _vehicle(speed: 60, ignition: true),
        overspeedThresholdKmh: 80,
      );
      expect(first, isEmpty);
      final second = FleetEventDetector.detect(
        previous: _vehicle(speed: 60, ignition: true),
        next: _vehicle(speed: 90, ignition: true),
        overspeedThresholdKmh: 80,
      );
      expect(second, hasLength(1));
    });

    test('at exactly the threshold does not fire', () {
      final events = FleetEventDetector.detect(
        previous: _vehicle(speed: 60, ignition: true),
        next: _vehicle(speed: 80, ignition: true),
        overspeedThresholdKmh: 80,
      );
      expect(events, isEmpty);
    });
  });

  group('FleetEventDetector.detect — geofence', () {
    final fence = Geofence(
      id: 'fence-1',
      vehicleKey: 'aargee:KL00XX0000',
      name: 'Home',
      latitude: 12.0,
      longitude: 75.0,
      radiusM: 250,
    );

    test('first sighting is silent, then a crossing fires', () {
      final insideById = <String, bool>{};
      final outside = FleetEventDetector.detect(
        previous: null,
        next: _vehicle(lat: 12.01, lon: 75.0),
        overspeedThresholdKmh: 80,
        geofences: [fence],
        insideByGeofenceId: insideById,
      );
      expect(outside, isEmpty);
      // The first sighting seeds the state; the crossing is detected
      // on the next snapshot.
      final entered = FleetEventDetector.detect(
        previous: _vehicle(lat: 12.01, lon: 75.0),
        next: _vehicle(lat: 12.0, lon: 75.0),
        overspeedThresholdKmh: 80,
        geofences: [fence],
        insideByGeofenceId: insideById,
      );
      expect(entered, hasLength(1));
      expect(entered.first.type, AlertType.geofenceEnter);
      final stillInside = FleetEventDetector.detect(
        previous: _vehicle(lat: 12.0, lon: 75.0),
        next: _vehicle(lat: 12.0, lon: 75.0),
        overspeedThresholdKmh: 80,
        geofences: [fence],
        insideByGeofenceId: insideById,
      );
      expect(stillInside, isEmpty);
    });

    test('entering then leaving fires enter then exit', () {
      final insideById = <String, bool>{};
      // Seed: outside.
      FleetEventDetector.detect(
        previous: null,
        next: _vehicle(lat: 12.01, lon: 75.0),
        overspeedThresholdKmh: 80,
        geofences: [fence],
        insideByGeofenceId: insideById,
      );
      final entered = FleetEventDetector.detect(
        previous: _vehicle(lat: 12.01, lon: 75.0),
        next: _vehicle(lat: 12.0, lon: 75.0),
        overspeedThresholdKmh: 80,
        geofences: [fence],
        insideByGeofenceId: insideById,
      );
      expect(entered, hasLength(1));
      expect(entered.first.type, AlertType.geofenceEnter);
      expect(entered.first.message, contains('Home'));
      final left = FleetEventDetector.detect(
        previous: _vehicle(lat: 12.0, lon: 75.0),
        next: _vehicle(lat: 12.01, lon: 75.0),
        overspeedThresholdKmh: 80,
        geofences: [fence],
        insideByGeofenceId: insideById,
      );
      expect(left, hasLength(1));
      expect(left.first.type, AlertType.geofenceExit);
    });

    test('a vehicle without a fix is skipped', () {
      final noFix = Vehicle(
        id: 'KL00XX0000',
        displayName: 'KL00XX0000',
        providerKey: 'aargee',
        status: VehicleStatus.unknown,
      );
      final events = FleetEventDetector.detect(
        previous: null,
        next: noFix,
        overspeedThresholdKmh: 80,
        geofences: [fence],
        insideByGeofenceId: {},
      );
      expect(events, isEmpty);
    });
  });

  group('FleetAlert JSON round-trip', () {
    test('toJson/fromJson preserves every field', () {
      final alert = FleetAlert(
        id: 'a1',
        type: AlertType.ignitionOff,
        severity: AlertSeverity.low,
        vehicleKey: 'aargee:KL00XX0000',
        vehicleName: 'KL00XX0000',
        time: DateTime(2026, 11, 12, 9, 59),
        latitude: 12.0,
        longitude: 75.0,
        message: 'Ignition turned off.',
      );
      final restored = FleetAlert.fromJson(alert.toJson());
      expect(restored.id, 'a1');
      expect(restored.type, AlertType.ignitionOff);
      expect(restored.severity, AlertSeverity.low);
      expect(restored.title, 'Ignition Off - KL00XX0000');
      expect(restored.latitude, 12.0);
      expect(restored.time, DateTime(2026, 11, 12, 9, 59));
    });
  });
}
