import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/models/provider_credentials.dart';
import 'package:unitrack/models/vehicle.dart';
import 'package:unitrack/services/providers/livetrace_client.dart';

// All values below are FAKE examples — never real reg numbers, IMEIs,
// user ids or keys.
void main() {
  group('LiveTraceClient.parseLiveData', () {
    const body = '''
{
  "response": {
    "LiveData": [
      {"Lat": 12.345678, "Lon": 75.012345, "Speed": 42.5,
       "Time": "2026-11-09 16:30:00", "Igni": true, "Nick": "BUS 01",
       "Reg_No": "KL00XX0000", "imei": "860000000000001"},
      {"Lat": 12.345, "Lon": 75.011, "Speed": 0,
       "Time": "2026-11-09 16:28:00", "Igni": false, "Nick": "BUS 02",
       "Reg_No": "KL00XX0001", "imei": "860000000000002"}
    ]
  }
}
''';

    test('parses both vehicles with live/idle status', () {
      final vehicles = LiveTraceClient.parseLiveData(body);
      expect(vehicles, hasLength(2));

      final first = vehicles[0];
      expect(first.displayName, 'KL00XX0000');
      expect(first.imei, '860000000000001');
      expect(first.latitude, 12.345678);
      expect(first.longitude, 75.012345);
      expect(first.speedKmph, 42.5);
      expect(first.ignition, isTrue);
      expect(first.status, VehicleStatus.live);
      expect(first.hasFix, isTrue);
      expect(first.lastUpdatedRaw, '2026-11-09 16:30:00');

      final second = vehicles[1];
      expect(second.displayName, 'KL00XX0001');
      expect(second.ignition, isFalse);
      expect(second.status, VehicleStatus.idle);
      expect(second.speedKmph, 0);
    });

    test('empty LiveData returns an empty list', () {
      expect(
        LiveTraceClient.parseLiveData('{"response": {"LiveData": []}}'),
        isEmpty,
      );
      expect(LiveTraceClient.parseLiveData('{}'), isEmpty);
    });
  });

  group('LiveTraceClient.splitAuth', () {
    test('option 1: IMEI device id + userid:key secret', () {
      final auth = LiveTraceClient.splitAuth(
        const ProviderCredentials(
          deviceId: '860000000000001',
          secret: 'demo_user:demo_key',
        ),
      );
      expect(auth.userId, 'demo_user');
      expect(auth.key, 'demo_key');
    });

    test('option 2: user id device id + key secret', () {
      final auth = LiveTraceClient.splitAuth(
        const ProviderCredentials(deviceId: 'demo_user', secret: 'demo_key'),
      );
      expect(auth.userId, 'demo_user');
      expect(auth.key, 'demo_key');
    });
  });
}
