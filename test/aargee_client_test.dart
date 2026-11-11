import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unitrack/models/provider_credentials.dart';
import 'package:unitrack/models/vehicle.dart';
import 'package:unitrack/services/providers/aargee_client.dart';
import 'package:unitrack/services/providers/gps_provider_client.dart';

// All values below are FAKE examples — never real reg numbers, IMEIs,
// vehicle ids or keys.
void main() {
  group('AargeeClient.parseLastData', () {
    test('parses the space-separated location string', () {
      final vehicles = AargeeClient.parseLastData({
        'status': 1,
        'data': [
          {
            'vehicle': 'KL00XX0000',
            'imei': '860000000000001',
            'ignition': true,
            'speed': 36.26,
            'location': '012.553665 075.037755',
            'time': '2026-11-09 16:39:44',
          },
        ],
      });
      expect(vehicles, hasLength(1));
      final vehicle = vehicles[0];
      expect(vehicle.displayName, 'KL00XX0000');
      expect(vehicle.imei, '860000000000001');
      expect(vehicle.latitude, 12.553665);
      expect(vehicle.longitude, 75.037755);
      expect(vehicle.speedKmph, 36.26);
      expect(vehicle.ignition, isTrue);
      expect(vehicle.status, VehicleStatus.live);
      expect(vehicle.hasFix, isTrue);
      expect(vehicle.lastUpdatedRaw, '2026-11-09 16:39:44');
    });

    test('parses split_latlng latitude/longitude fields', () {
      final vehicles = AargeeClient.parseLastData({
        'status': 1,
        'data': [
          {
            'vehicle': 'KL00XX0001',
            'imei': '860000000000002',
            'ignition': false,
            'speed': 0.0,
            'latitude': '012.125795',
            'longitude': '078.454375',
            'time': '2026-11-09 14:17:35',
          },
        ],
      });
      expect(vehicles, hasLength(1));
      expect(vehicles[0].latitude, 12.125795);
      expect(vehicles[0].longitude, 78.454375);
      expect(vehicles[0].status, VehicleStatus.idle);
    });
  });

  group('AargeeClient.parseVehicleList', () {
    test('parses get_all_vehicles entries without a fix', () {
      final vehicles = AargeeClient.parseVehicleList({
        'status': 1,
        'data': [
          {
            'vehicle_number': 'KL00XX0000',
            'vehicle_id': 10001,
            'imei': '860000000000001',
          },
        ],
      });
      expect(vehicles, hasLength(1));
      expect(vehicles[0].id, '10001');
      expect(vehicles[0].displayName, 'KL00XX0000');
      expect(vehicles[0].hasFix, isFalse);
      expect(vehicles[0].status, VehicleStatus.unknown);
    });
  });

  group('AargeeClient.checkStatus', () {
    test('status 1 passes', () {
      expect(() => AargeeClient.checkStatus({'status': 1}), returnsNormally);
    });

    test('error statuses throw ProviderException with a clear message', () {
      final cases = {
        0: 'Server error',
        2: 'not active',
        3: 'not assigned',
        4: 'limit reached',
        5: 'not available',
      };
      for (final entry in cases.entries) {
        expect(
          () => AargeeClient.checkStatus({'status': entry.key}),
          throwsA(
            isA<ProviderException>().having(
              (e) => e.message,
              'message',
              contains(entry.value),
            ),
          ),
        );
      }
    });
  });

  group('AargeeClient.fetchLiveVehicles device matching', () {
    const body = '''
{"status": 1, "data": [
  {"vehicle": "KL00XX0000", "imei": "860000000000001", "ignition": true,
   "speed": 36.26, "location": "012.553665 075.037755",
   "time": "2026-11-09 16:39:44"},
  {"vehicle": "KL00XX0001", "imei": "860000000000002", "ignition": false,
   "speed": 0, "location": "012.553665 075.037755",
   "time": "2026-11-09 16:35:00"}
]}
''';

    test('an IMEI device id returns only that vehicle', () async {
      final mock = MockClient((_) async => http.Response(body, 200));
      final vehicles = await AargeeClient().fetchLiveVehicles(
        const ProviderCredentials(
          deviceId: '860000000000002',
          secret: 'fake-key',
        ),
        httpClient: mock,
      );
      expect(vehicles, hasLength(1));
      expect(vehicles[0].imei, '860000000000002');
    });

    test('a vehicle number returns only that vehicle', () async {
      final mock = MockClient((_) async => http.Response(body, 200));
      final vehicles = await AargeeClient().fetchLiveVehicles(
        const ProviderCredentials(deviceId: 'KL00XX0001', secret: 'fake-key'),
        httpClient: mock,
      );
      expect(vehicles, hasLength(1));
      expect(vehicles[0].displayName, 'KL00XX0001');
    });

    test('an unknown device ID throws a clear error', () async {
      final mock = MockClient((_) async => http.Response(body, 200));
      expect(
        () => AargeeClient().fetchLiveVehicles(
          const ProviderCredentials(
            deviceId: '869999999999999',
            secret: 'fake-key',
          ),
          httpClient: mock,
        ),
        throwsA(isA<ProviderException>()),
      );
    });
  });
}
