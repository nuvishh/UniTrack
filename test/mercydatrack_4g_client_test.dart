import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unitrack/models/provider_credentials.dart';
import 'package:unitrack/models/vehicle.dart';
import 'package:unitrack/services/providers/gps_provider_client.dart';
import 'package:unitrack/services/providers/mercydatrack_4g_client.dart';
import 'package:unitrack/services/providers/provider_client_factory.dart';

// All values below are FAKE examples — never real reg numbers, chassis
// numbers, IMEIs, vehicle ids or keys.
void main() {
  group('MercyDataTrack4GClient.fetchLiveVehicles', () {
    // Points deliberately NOT in newest-first order: the client must
    // pick the latest point by time, not just the first element.
    const body = '''
{"status": "success", "code": 200, "data": {
  "date": "12-11-2026",
  "vehicle_registration": "FAKECHASSIS0000001",
  "data": [
    {"latitude": "011.111111", "longitude": "075.111111", "ignition": "OFF", "mainPower": "connected", "sourceTime": "04:10:18 PM", "speed": "0.0"},
    {"latitude": "012.345678", "longitude": "075.012345", "ignition": "ON", "mainPower": "connected", "sourceTime": "04:22:18 PM", "speed": "12.5"}
  ]
}}
''';

    const credentials = ProviderCredentials(
      deviceId: 'FAKECHASSIS0000001',
      secret: 'demo_user:demo_pass',
    );

    test('returns the requested vehicle at its latest point', () async {
      final mock = MockClient((_) async => http.Response(body, 200));
      final vehicles = await MercyDataTrack4GClient().fetchLiveVehicles(
        credentials,
        httpClient: mock,
      );
      expect(vehicles, hasLength(1));
      final vehicle = vehicles[0];
      expect(vehicle.id, 'FAKECHASSIS0000001');
      expect(vehicle.displayName, 'FAKECHASSIS0000001');
      expect(vehicle.providerKey, 'mercydatrack4g');
      expect(vehicle.imei, isNull);
      expect(vehicle.latitude, 12.345678);
      expect(vehicle.longitude, 75.012345);
      expect(vehicle.ignition, isTrue);
      expect(vehicle.status, VehicleStatus.live);
      expect(vehicle.speedKmph, 12.5);
      expect(vehicle.lastUpdated, DateTime(2026, 11, 12, 16, 22, 18));
    });

    test('a non-success status throws a clear error', () async {
      final mock = MockClient(
        (_) async => http.Response('{"status":"error","code":401}', 200),
      );
      expect(
        () => MercyDataTrack4GClient().fetchLiveVehicles(
          credentials,
          httpClient: mock,
        ),
        throwsA(isA<ProviderException>()),
      );
    });

    test('a non-200 HTTP status throws a clear error', () async {
      final mock = MockClient((_) async => http.Response('oops', 500));
      expect(
        () => MercyDataTrack4GClient().fetchLiveVehicles(
          credentials,
          httpClient: mock,
        ),
        throwsA(isA<ProviderException>()),
      );
    });

    test('a different registration in the response throws', () async {
      final mock = MockClient(
        (_) async => http.Response(
          body.replaceAll('FAKECHASSIS0000001', 'FAKECHASSIS0000002'),
          200,
        ),
      );
      expect(
        () => MercyDataTrack4GClient().fetchLiveVehicles(
          credentials,
          httpClient: mock,
        ),
        throwsA(isA<ProviderException>()),
      );
    });

    test('an empty points array throws a clear error', () async {
      final mock = MockClient(
        (_) async => http.Response(
          '{"status":"success","code":200,"data":{'
          '"date":"12-11-2026",'
          '"vehicle_registration":"FAKECHASSIS0000001","data":[]}}',
          200,
        ),
      );
      expect(
        () => MercyDataTrack4GClient().fetchLiveVehicles(
          credentials,
          httpClient: mock,
        ),
        throwsA(isA<ProviderException>()),
      );
    });
  });

  group('provider factory', () {
    test('mercydatrack4g resolves to the 4G client', () {
      expect(clientForKey('mercydatrack4g'), isA<MercyDataTrack4GClient>());
    });
  });
}
