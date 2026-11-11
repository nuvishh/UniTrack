import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unitrack/models/provider_credentials.dart';
import 'package:unitrack/models/vehicle.dart';
import 'package:unitrack/services/providers/gps_provider_client.dart';
import 'package:unitrack/services/providers/mercydatrack_client.dart';
import 'package:unitrack/utils/parsing.dart';

// All values below are FAKE examples — never real reg numbers, IMEIs,
// vehicle ids or keys.
void main() {
  group('MercyDataTrackClient.splitAuth', () {
    test('username:password splits at the first colon', () {
      final auth = MercyDataTrackClient.splitAuth(
        const ProviderCredentials(
          deviceId: 'KL00XX0000',
          secret: 'demo_user:demo:pass',
        ),
      );
      expect(auth.username, 'demo_user');
      expect(auth.password, 'demo:pass');
    });

    test('a secret without a colon throws a clear error', () {
      expect(
        () => MercyDataTrackClient.splitAuth(
          const ProviderCredentials(
            deviceId: 'KL00XX0000',
            secret: 'demo_password',
          ),
        ),
        throwsA(isA<ProviderException>()),
      );
    });
  });

  group('MercyDataTrackClient.fetchLiveVehicles', () {
    const body = '''
{"status": "success", "code": 200, "data": {
  "vehicle_registration": "KL00XX0000",
  "imei_no": "860000000000001",
  "latitude": "012.345678",
  "ignition": "OFF",
  "serial_no": "FAKE0001",
  "speed": 0.0,
  "longitude": "075.012345",
  "source_date": "11-11-2026 03:34:32 PM"
}}
''';

    const credentials = ProviderCredentials(
      deviceId: 'KL00XX0000',
      secret: 'demo_user:demo_pass',
    );

    test('returns the requested vehicle with parsed fields', () async {
      final mock = MockClient((_) async => http.Response(body, 200));
      final vehicles = await MercyDataTrackClient().fetchLiveVehicles(
        credentials,
        httpClient: mock,
      );
      expect(vehicles, hasLength(1));
      final vehicle = vehicles[0];
      expect(vehicle.id, 'KL00XX0000');
      expect(vehicle.displayName, 'KL00XX0000');
      expect(vehicle.imei, '860000000000001');
      expect(vehicle.latitude, 12.345678);
      expect(vehicle.longitude, 75.012345);
      expect(vehicle.ignition, isFalse);
      expect(vehicle.status, VehicleStatus.idle);
      expect(vehicle.speedKmph, 0.0);
      expect(vehicle.lastUpdated, DateTime(2026, 11, 11, 15, 34, 32));
    });

    test('a non-success status throws a clear error', () async {
      final mock = MockClient(
        (_) async => http.Response('{"status":"error","code":401}', 200),
      );
      expect(
        () => MercyDataTrackClient().fetchLiveVehicles(
          credentials,
          httpClient: mock,
        ),
        throwsA(isA<ProviderException>()),
      );
    });

    test('a non-200 HTTP status throws a clear error', () async {
      final mock = MockClient((_) async => http.Response('oops', 500));
      expect(
        () => MercyDataTrackClient().fetchLiveVehicles(
          credentials,
          httpClient: mock,
        ),
        throwsA(isA<ProviderException>()),
      );
    });

    test('a different registration in the response throws', () async {
      final mock = MockClient(
        (_) async => http.Response(
          body.replaceAll('KL00XX0000', 'KL00XX0001'),
          200,
        ),
      );
      expect(
        () => MercyDataTrackClient().fetchLiveVehicles(
          credentials,
          httpClient: mock,
        ),
        throwsA(isA<ProviderException>()),
      );
    });
  });

  group('parseDayMonthYearTime', () {
    test('parses PM times to 24-hour clock', () {
      expect(
        parseDayMonthYearTime('11-11-2026 03:34:32 PM'),
        DateTime(2026, 11, 11, 15, 34, 32),
      );
      expect(
        parseDayMonthYearTime('11-11-2026 12:05:00 PM'),
        DateTime(2026, 11, 11, 12, 5),
      );
    });

    test('parses AM times, including 12 AM as midnight', () {
      expect(
        parseDayMonthYearTime('11-11-2026 09:05:00 AM'),
        DateTime(2026, 11, 11, 9, 5),
      );
      expect(
        parseDayMonthYearTime('11-11-2026 12:05:00 AM'),
        DateTime(2026, 11, 11, 0, 5),
      );
    });

    test('returns null for unparseable values', () {
      expect(parseDayMonthYearTime('2026-11-11 15:34:32'), isNull);
      expect(parseDayMonthYearTime('not a date'), isNull);
      expect(parseDayMonthYearTime(null), isNull);
    });
  });
}
