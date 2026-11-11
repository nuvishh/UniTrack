import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unitrack/models/provider_credentials.dart';
import 'package:unitrack/services/providers/gps_provider_client.dart';
import 'package:unitrack/services/providers/transight_client.dart';

// All values below are FAKE examples — never real reg numbers, IMEIs,
// vehicle ids or keys.
void main() {
  group('TransightClient.checkStatus', () {
    test('status 1 passes', () {
      TransightClient.checkStatus({'status': 1});
    });

    test('error statuses throw with a clear message', () {
      const cases = {
        0: 'Server error',
        2: 'not active',
        3: 'not assigned',
        4: 'limit reached',
        5: 'not available',
      };
      for (final entry in cases.entries) {
        expect(
          () => TransightClient.checkStatus({'status': entry.key}),
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

  group('TransightClient.fetchLiveVehicles device matching', () {
    const body = '''
{"status": 1, "data": [
  {"vehicle": "KL00XX0000", "imei": "860000000000001", "ignition": true,
   "speed": 36.26, "latitude": "12.345678", "longitude": "75.012345",
   "time": "2026-11-11 16:24:14"},
  {"vehicle": "KL00XX0001", "imei": "860000000000002", "ignition": false,
   "speed": 0, "latitude": "12.345678", "longitude": "75.012345",
   "time": "2026-11-11 16:24:14"}
]}
''';

    test('an IMEI device id returns only that vehicle', () async {
      final mock = MockClient((_) async => http.Response(body, 200));
      final vehicles = await TransightClient().fetchLiveVehicles(
        const ProviderCredentials(
          deviceId: '860000000000002',
          secret: 'fake-key',
        ),
        httpClient: mock,
      );
      expect(vehicles, hasLength(1));
      expect(vehicles[0].imei, '860000000000002');
      expect(vehicles[0].providerKey, 'transight');
    });

    test('an unknown device ID throws a clear error', () async {
      final mock = MockClient((_) async => http.Response(body, 200));
      expect(
        () => TransightClient().fetchLiveVehicles(
          const ProviderCredentials(
            deviceId: '869999999999999',
            secret: 'fake-key',
          ),
          httpClient: mock,
        ),
        throwsA(isA<ProviderException>()),
      );
    });

    test('an empty device id returns the whole fleet', () async {
      final mock = MockClient((_) async => http.Response(body, 200));
      final vehicles = await TransightClient().fetchLiveVehicles(
        const ProviderCredentials(deviceId: '', secret: 'fake-key'),
        httpClient: mock,
      );
      expect(vehicles, hasLength(2));
    });
  });

  group('TransightClient.fetchHistory', () {
    test('a 15-digit device id is sent as imei', () async {
      String? sentBody;
      final mock = MockClient((request) async {
        sentBody = request.body;
        return http.Response(
          '{"status": 1, "data": ['
          '{"vehicle": "KL00XX0000", "imei": "860000000000001", '
          '"ignition": true, "speed": 10.5, '
          '"latitude": "12.345678", "longitude": "75.012345", '
          '"time": "2026-11-11 16:24:14"}]}',
          200,
        );
      });
      final points = await TransightClient().fetchHistory(
        const ProviderCredentials(
          deviceId: '860000000000001',
          secret: 'fake-key',
        ),
        from: DateTime(2026, 11, 11, 10),
        to: DateTime(2026, 11, 11, 16),
        httpClient: mock,
      );
      expect(points, hasLength(1));
      expect(points[0].speedKmph, 10.5);
      final sent = jsonDecode(sentBody!) as Map<String, dynamic>;
      expect(sent['imei'], '860000000000001');
      expect(sent.containsKey('vehicle_id'), isFalse);
    });

    test('a short numeric device id is sent as vehicle_id', () async {
      String? sentBody;
      final mock = MockClient((request) async {
        sentBody = request.body;
        return http.Response('{"status": 1, "data": []}', 200);
      });
      await TransightClient().fetchHistory(
        const ProviderCredentials(deviceId: '123456', secret: 'fake-key'),
        from: DateTime(2026, 11, 11, 10),
        to: DateTime(2026, 11, 11, 16),
        httpClient: mock,
      );
      final sent = jsonDecode(sentBody!) as Map<String, dynamic>;
      expect(sent['vehicle_id'], '123456');
    });
  });

  group('TransightClient.parseLastDataItem', () {
    test('parses the location string when split fields are absent', () {
      final vehicle = TransightClient.parseLastDataItem({
        'vehicle': 'KL00XX0000',
        'imei': '860000000000001',
        'ignition': false,
        'speed': 0,
        'location': '012.345678 075.012345',
        'time': '2026-11-11 16:24:14',
      });
      expect(vehicle.latitude, 12.345678);
      expect(vehicle.longitude, 75.012345);
      expect(vehicle.providerKey, 'transight');
    });
  });
}
