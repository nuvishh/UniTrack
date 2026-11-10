import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/models/provider_credentials.dart';
import 'package:unitrack/models/vehicle.dart';
import 'package:unitrack/services/providers/simplytrack_client.dart';

// All values below are FAKE examples — never real reg numbers, IMEIs,
// user ids or keys.
void main() {
  group('SimplyTrackClient.parseVehicleList', () {
    const body = '''
[
  {"lat": 21.14277777777777, "lon": 78.75641333333333, "status": "Stopped",
   "speed": 5, "time": "2026-11-09T09:17:43.029Z",
   "imei": "860000000000001", "regno": "KL00XX0000", "vehicleType": "BUS",
   "engineOn": false},
  {"lat": 21.143, "lon": 78.757, "status": "Unreachable", "speed": null,
   "time": "2026-11-09T09:10:00.000Z", "imei": "860000000000002",
   "regno": "KL00XX0001", "vehicleType": "BUS", "engineOn": null}
]
''';

    test('parses stopped and unreachable vehicles', () {
      final vehicles = SimplyTrackClient.parseVehicleList(body);
      expect(vehicles, hasLength(2));

      final stopped = vehicles[0];
      expect(stopped.displayName, 'KL00XX0000');
      expect(stopped.imei, '860000000000001');
      expect(stopped.latitude, 21.14277777777777);
      expect(stopped.speedKmph, 5);
      expect(stopped.ignition, isFalse);
      expect(stopped.status, VehicleStatus.idle);
      expect(stopped.lastUpdated?.isUtc, isTrue);

      final unreachable = vehicles[1];
      expect(unreachable.speedKmph, isNull);
      expect(unreachable.status, VehicleStatus.unknown);
    });

    test('track-data direction fields do not break parsing', () {
      const trackBody = '''
[
  {"lat": 17.744526666666665, "lon": 77.75447111111112, "status": "Stopped",
   "speed": 1, "time": "2026-11-09T09:29:40Z",
   "imei": "860000000000001", "regno": "KL00XX0000", "vehicleType": "BUS",
   "engineOn": false, "direction": 143.77, "directionCardinal": "SE"}
]
''';
      final vehicles = SimplyTrackClient.parseVehicleList(trackBody);
      expect(vehicles, hasLength(1));
      expect(vehicles[0].status, VehicleStatus.idle);
      expect(vehicles[0].rawJson['directionCardinal'], 'SE');
    });

    test('a single object (not an array) is wrapped', () {
      const singleBody = '''
{"lat": 21.14, "lon": 78.75, "status": "Stopped", "speed": 0,
 "time": "2026-11-09T09:00:00Z", "imei": "860000000000001",
 "regno": "KL00XX0000", "engineOn": false}
''';
      final vehicles = SimplyTrackClient.parseVehicleList(singleBody);
      expect(vehicles, hasLength(1));
    });
  });

  group('SimplyTrackClient.splitCredentials', () {
    test('option 1: IMEI device id + userId:apiKey secret', () {
      final auth = SimplyTrackClient.splitCredentials(
        const ProviderCredentials(
          deviceId: '860000000000001',
          secret: 'demo_user:demo_api_key',
        ),
      );
      expect(auth.userId, 'demo_user');
      expect(auth.apiKey, 'demo_api_key');
      expect(auth.imei, '860000000000001');
    });

    test('option 2: userId:imei device id + apiKey secret', () {
      final auth = SimplyTrackClient.splitCredentials(
        const ProviderCredentials(
          deviceId: 'demo_user:860000000000001',
          secret: 'demo_api_key',
        ),
      );
      expect(auth.userId, 'demo_user');
      expect(auth.apiKey, 'demo_api_key');
      expect(auth.imei, '860000000000001');
    });
  });
}
