import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unitrack/models/provider_credentials.dart';
import 'package:unitrack/models/vehicle.dart';
import 'package:unitrack/services/providers/avlview_client.dart';
import 'package:unitrack/services/providers/gps_provider_client.dart';

// All values below are FAKE examples — never real reg numbers, IMEIs,
// vehicle ids, plate IDs or keys.
void main() {
  group('AvlViewClient.parseStatusList', () {
    test('parses a moving snapshot', () {
      final vehicles = AvlViewClient.parseStatusList([
        {
          'vehicleId': '11111111-2222-3333-4444-555555555555',
          'vehId': 10001,
          'imei': '860000000000001',
          'vehicleName': 'Veh 001',
          'plateNumber': 'KL00XX0000',
          'dateTime': '2026-11-26 12:27:53',
          'status': 'M',
          'latitude': 11.2587,
          'longitude': 75.7804,
          'speed': 18.0,
          'ignition': 'Y',
          'odometer': 2545.74,
        },
      ]);
      expect(vehicles, hasLength(1));
      final vehicle = vehicles[0];
      expect(vehicle.id, '11111111-2222-3333-4444-555555555555');
      expect(vehicle.displayName, 'KL00XX0000');
      expect(vehicle.imei, '860000000000001');
      expect(vehicle.latitude, 11.2587);
      expect(vehicle.longitude, 75.7804);
      expect(vehicle.speedKmph, 18.0);
      expect(vehicle.ignition, isTrue);
      expect(vehicle.status, VehicleStatus.live);
      expect(vehicle.hasFix, isTrue);
      expect(vehicle.lastUpdatedRaw, '2026-11-26 12:27:53');
    });

    test('stopped maps to idle, disconnected to unknown', () {
      final vehicles = AvlViewClient.parseStatusList([
        {
          'vehicleId': '11111111-2222-3333-4444-555555555555',
          'plateNumber': 'KL00XX0000',
          'dateTime': '2026-11-26 12:00:00',
          'status': 'S',
          'latitude': 11.2587,
          'longitude': 75.7804,
          'speed': 0.0,
          'ignition': 'N',
        },
        {
          'vehicleId': '22222222-3333-4444-5555-666666666666',
          'plateNumber': 'KL00XX0001',
          'dateTime': '2026-11-26 11:00:00',
          'status': 'D',
          'latitude': 0.0,
          'longitude': 0.0,
          'speed': 0.0,
          'ignition': 'U',
        },
      ]);
      expect(vehicles, hasLength(2));
      expect(vehicles[0].status, VehicleStatus.idle);
      expect(vehicles[0].ignition, isFalse);
      expect(vehicles[1].status, VehicleStatus.unknown);
      expect(vehicles[1].ignition, isNull);
      expect(vehicles[1].hasFix, isFalse);
    });
  });

  group('AvlViewClient.parseVehicleList', () {
    test('parses /vehicles entries without a fix', () {
      final vehicles = AvlViewClient.parseVehicleList([
        {
          'vehicleId': 10001,
          'plateId': '11111111-2222-3333-4444-555555555555',
          'vehicleName': 'Veh 001',
          'plateNumber': 'KL00XX0000',
          'imei': '860000000000001',
          'model': 'Tiago',
        },
      ]);
      expect(vehicles, hasLength(1));
      expect(vehicles[0].id, '11111111-2222-3333-4444-555555555555');
      expect(vehicles[0].displayName, 'KL00XX0000');
      expect(vehicles[0].hasFix, isFalse);
      expect(vehicles[0].status, VehicleStatus.unknown);
    });
  });

  group('AvlViewClient.parseRawData', () {
    test('parses the wrapped vehiclerRawDetail list', () {
      final vehicles = AvlViewClient.parseRawData({
        'status': 200,
        'vehiclerRawDetail': [
          {
            'vehicleId': 0,
            'vehicleName': 'KL00XX0000',
            'dateTime': '2026-11-26 10:00:00',
            'speed': 13,
            'distance': 13.0,
            'status': 'MOVING',
            'ignitionOn': 'Y',
            'imeiNumber': '860000000000001',
            'plateNo': 'KL00XX0000',
            'plateId': '11111111-2222-3333-4444-555555555555',
            'longitude': 75.4061,
            'latitude': 11.8670,
          },
          {
            'vehicleId': 0,
            'vehicleName': 'KL00XX0000',
            'dateTime': '2026-11-26 10:05:00',
            'speed': 0,
            'distance': 22.0,
            'status': 'STOPPED',
            'ignitionOn': 'Y',
            'imeiNumber': '860000000000001',
            'plateNo': 'KL00XX0000',
            'plateId': '11111111-2222-3333-4444-555555555555',
            'longitude': 75.4067,
            'latitude': 11.8666,
          },
        ],
        'timeRangeException': null,
      });
      expect(vehicles, hasLength(2));
      expect(vehicles[0].latitude, 11.867);
      expect(vehicles[0].longitude, 75.4061);
      expect(vehicles[0].speedKmph, 13.0);
      expect(vehicles[0].ignition, isTrue);
      expect(vehicles[0].status, VehicleStatus.live);
      expect(vehicles[0].lastUpdatedRaw, '2026-11-26 10:00:00');
      expect(vehicles[1].status, VehicleStatus.idle);
    });

    test('accepts a bare array too', () {
      final vehicles = AvlViewClient.parseRawData([
        {
          'dateTime': '2026-11-26 10:00:00',
          'speed': 5,
          'status': 'MOVING',
          'ignitionOn': 'N',
          'plateNo': 'KL00XX0000',
          'plateId': '11111111-2222-3333-4444-555555555555',
          'longitude': 75.4,
          'latitude': 11.8,
        },
      ]);
      expect(vehicles, hasLength(1));
      expect(vehicles[0].ignition, isFalse);
    });
  });

  group('AvlViewClient.fetchLiveVehicles device matching', () {
    const body = '''
[
  {"vehicleId": "11111111-2222-3333-4444-555555555555", "vehId": 10001,
   "imei": "860000000000001", "plateNumber": "KL00XX0000",
   "dateTime": "2026-11-26 12:27:53", "status": "M",
   "latitude": 11.2587, "longitude": 75.7804, "speed": 18.0,
   "ignition": "Y"},
  {"vehicleId": "22222222-3333-4444-5555-666666666666", "vehId": 10002,
   "imei": "860000000000002", "plateNumber": "KL00XX0001",
   "dateTime": "2026-11-26 12:20:00", "status": "S",
   "latitude": 11.2500, "longitude": 75.7800, "speed": 0,
   "ignition": "N"}
]
''';

    test('a plate number returns only that vehicle', () async {
      final mock = MockClient((_) async => http.Response(body, 200));
      final vehicles = await AvlViewClient().fetchLiveVehicles(
        const ProviderCredentials(deviceId: 'KL00XX0001', secret: 'fake-key'),
        httpClient: mock,
      );
      expect(vehicles, hasLength(1));
      expect(vehicles[0].displayName, 'KL00XX0001');
    });

    test('an IMEI returns only that vehicle', () async {
      final mock = MockClient((_) async => http.Response(body, 200));
      final vehicles = await AvlViewClient().fetchLiveVehicles(
        const ProviderCredentials(
          deviceId: '860000000000001',
          secret: 'fake-key',
        ),
        httpClient: mock,
      );
      expect(vehicles, hasLength(1));
      expect(vehicles[0].imei, '860000000000001');
    });

    test('an unknown device ID throws a clear error', () async {
      final mock = MockClient((_) async => http.Response(body, 200));
      expect(
        () => AvlViewClient().fetchLiveVehicles(
          const ProviderCredentials(
            deviceId: 'KL00XX9999',
            secret: 'fake-key',
          ),
          httpClient: mock,
        ),
        throwsA(isA<ProviderException>()),
      );
    });

    test('a 401 throws an invalid-key error', () async {
      final mock = MockClient(
        (_) async => http.Response('Unauthorized', 401),
      );
      expect(
        () => AvlViewClient().fetchLiveVehicles(
          const ProviderCredentials(deviceId: '', secret: 'bad-key'),
          httpClient: mock,
        ),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.message,
            'message',
            contains('invalid API key'),
          ),
        ),
      );
    });
  });

  group('AvlViewClient.fetchHistory', () {
    test('resolves a plate number to its plateId, then filters points '
        'to the requested window', () async {
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/v3.1/vehicles')) {
          return http.Response(
            '[{"vehicleId": 10001, '
            '"plateId": "11111111-2222-3333-4444-555555555555", '
            '"plateNumber": "KL00XX0000", "imei": "860000000000001"}]',
            200,
          );
        }
        if (request.url.path.endsWith('/v3.1/vehicleRawData')) {
          expect(
            request.url.queryParameters['plateCode'],
            '11111111-2222-3333-4444-555555555555',
          );
          expect(request.url.queryParameters['fromDate'], '2026-11-26');
          expect(request.url.queryParameters['toDate'], '2026-11-26');
          return http.Response(
            '{"status": 200, "vehiclerRawDetail": ['
            '{"dateTime": "2026-11-26 10:00:00", "speed": 13, '
            '"status": "MOVING", "ignitionOn": "Y", '
            '"plateNo": "KL00XX0000", '
            '"plateId": "11111111-2222-3333-4444-555555555555", '
            '"longitude": 75.4061, "latitude": 11.8670}, '
            '{"dateTime": "2026-11-26 12:00:00", "speed": 20, '
            '"status": "MOVING", "ignitionOn": "Y", '
            '"plateNo": "KL00XX0000", '
            '"plateId": "11111111-2222-3333-4444-555555555555", '
            '"longitude": 75.4100, "latitude": 11.8600}'
            '], "timeRangeException": null}',
            200,
          );
        }
        return http.Response('Not found', 404);
      });
      final points = await AvlViewClient().fetchHistory(
        const ProviderCredentials(deviceId: 'KL00XX0000', secret: 'fake-key'),
        from: DateTime(2026, 11, 26, 9),
        to: DateTime(2026, 11, 26, 11),
        httpClient: mock,
      );
      expect(points, hasLength(1));
      expect(points[0].lastUpdated, DateTime(2026, 11, 26, 10));
    });

    test('a plateId UUID passes through without a list lookup', () async {
      var listCalls = 0;
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/v3.1/vehicles')) {
          listCalls++;
          return http.Response('[]', 200);
        }
        return http.Response(
          '{"status": 200, "vehiclerRawDetail": [], '
          '"timeRangeException": null}',
          200,
        );
      });
      final points = await AvlViewClient().fetchHistory(
        const ProviderCredentials(
          deviceId: '11111111-2222-3333-4444-555555555555',
          secret: 'fake-key',
        ),
        from: DateTime(2026, 11, 26, 9),
        to: DateTime(2026, 11, 26, 11),
        httpClient: mock,
      );
      expect(points, isEmpty);
      expect(listCalls, 0);
    });
  });
}
