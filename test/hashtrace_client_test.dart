import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/models/vehicle.dart';
import 'package:unitrack/services/providers/hashtrace_client.dart';

// All values below are FAKE examples — never real reg numbers, IMEIs,
// vehicle ids or keys.
void main() {
  group('HashTraceClient.parseVehicleList', () {
    const body = '''
[
  {"VId": 10001, "VName": "BUS 01", "Imei": "860000000000001",
   "VPlate": "KL00XX0000", "TTime": "2026-11-09T16:01:46",
   "Lat": "12.5383540", "Lon": "75.0022600", "Ign": true, "Spd": 0,
   "Dir": 0.0, "MVolt": 12.5, "Batt": 4.1},
  {"VId": 10002, "VName": "BUS 02", "Imei": "860000000000002",
   "VPlate": "KL00XX0001", "TTime": "2026-11-09T15:58:10",
   "Lat": "12.5400000", "Lon": "75.0030000", "Ign": false, "Spd": 0,
   "Dir": 90.0, "MVolt": 12.4, "Batt": 4.0}
]
''';

    test('parses string lat/lon and ignition states', () {
      final vehicles = HashTraceClient.parseVehicleList(body);
      expect(vehicles, hasLength(2));

      final first = vehicles[0];
      expect(first.id, '10001');
      expect(first.displayName, 'KL00XX0000');
      expect(first.imei, '860000000000001');
      // Lat/Lon arrive as strings — they must be parsed to numbers.
      expect(first.latitude, 12.538354);
      expect(first.longitude, 75.00226);
      expect(first.ignition, isTrue);
      expect(first.status, VehicleStatus.live);
      expect(first.hasFix, isTrue);

      final second = vehicles[1];
      expect(second.ignition, isFalse);
      expect(second.status, VehicleStatus.idle);
    });

    test('empty array (also what a wrong key returns) parses to []', () {
      expect(HashTraceClient.parseVehicleList('[]'), isEmpty);
    });

    test('sentinel records inside a list are skipped', () {
      const withSentinel = '''
[
  {"VId": 0, "VName": "_Expired", "Imei": null, "VPlate": "_Expired",
   "TTime": "0001-01-01T00:00:00", "Lat": "0.00", "Lon": "0.00",
   "Ign": false, "Spd": 0, "Dir": 0.0, "MVolt": 0.0, "Batt": 0.0},
  {"VId": 10001, "VName": "BUS 01", "Imei": "860000000000001",
   "VPlate": "KL00XX0000", "TTime": "2026-11-09T16:01:46",
   "Lat": "12.5383540", "Lon": "75.0022600", "Ign": true, "Spd": 0,
   "Dir": 0.0, "MVolt": 12.5, "Batt": 4.1}
]
''';
      final vehicles = HashTraceClient.parseVehicleList(withSentinel);
      expect(vehicles, hasLength(1));
      expect(vehicles[0].id, '10001');
    });
  });

  group('HashTraceClient.parseVehicle sentinel', () {
    test('unknown/expired vehicle id becomes an expired vehicle', () {
      const sentinel = {
        'VId': 0,
        'VName': '_Expired',
        'Imei': null,
        'VPlate': '_Expired',
        'TTime': '0001-01-01T00:00:00',
        'Lat': '0.00',
        'Lon': '0.00',
        'Ign': false,
        'Spd': 0,
        'Dir': 0.0,
        'MVolt': 0.0,
        'Batt': 0.0,
      };
      expect(HashTraceClient.isExpiredSentinel(sentinel), isTrue);
      final vehicle = HashTraceClient.parseVehicle(sentinel);
      expect(vehicle.status, VehicleStatus.expired);
      // Never plot the sentinel's 0,0 coordinates.
      expect(vehicle.hasFix, isFalse);
    });

    test('a real vehicle is not a sentinel', () {
      expect(
        HashTraceClient.isExpiredSentinel({'VId': 10001, 'VName': 'BUS 01'}),
        isFalse,
      );
    });
  });
}
