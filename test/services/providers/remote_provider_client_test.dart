import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unitrack/models/provider_credentials.dart';
import 'package:unitrack/models/provider_registry.dart';
import 'package:unitrack/services/providers/gps_provider_client.dart';
import 'package:unitrack/services/providers/remote_provider_client.dart';

// All values below are FAKE examples — never real reg numbers, IMEIs,
// vehicle ids or keys.
void main() {
  group('RemoteProviderClient — HashTrace shape', () {
    late RegistryEntry entry;

    setUp(() {
      entry = parseProviderRegistry('''
{
  "version": 1,
  "providers": [
    {"key": "hashtrace", "displayName": "HashTrace",
     "baseUrl": "https://cdn.hashtrace.com/api/Tracker",
     "auth": {"style": "query", "param": "authKey", "secretFormat": "key"},
     "authKind": "apiKey",
     "deviceIdLabel": "Vehicle ID / IMEI", "secretLabel": "Auth Key",
     "supportsHistory": false, "verified": true,
     "genericCompatible": true, "timeoutSeconds": 20,
     "fleet": {"method": "GET", "path": "/All",
               "query": {"authKey": "{secret}"}},
     "fields": {"id": "VId", "displayName": "VName", "imei": "Imei",
                "latitude": "Lat", "longitude": "Lon", "ignition": "Ign",
                "speed": "Spd", "lastUpdated": "TTime",
                "trueValues": ["true", "1"], "falseValues": ["false", "0"]}}
  ]
}
''').entryFor('hashtrace')!;
    });

    test('GET with authKey query param, flat array, string lat/lon', () async {
      Uri? seenUri;
      final client = MockClient((request) async {
        seenUri = request.url;
        return http.Response(
          jsonEncode([
            {
              "VId": 10001,
              "VName": "BUS 01",
              "Imei": "860000000000001",
              "VPlate": "KL00XX0000",
              "TTime": "2026-11-09T16:01:46",
              "Lat": "12.5383540",
              "Lon": "75.0022600",
              "Ign": true,
              "Spd": 0,
              "Dir": 0.0,
              "MVolt": 12.5,
              "Batt": 4.1,
            },
          ]),
          200,
        );
      });
      final vehicles = await RemoteProviderClient(
        entry,
      ).fetchLiveVehicles(
        const ProviderCredentials(deviceId: '10001', secret: 'fake-key'),
        httpClient: client,
      );
      expect(seenUri.toString(), contains('authKey=fake-key'));
      expect(vehicles, hasLength(1));
      expect(vehicles.first.id, '10001');
      expect(vehicles.first.displayName, 'BUS 01');
      expect(vehicles.first.imei, '860000000000001');
      expect(vehicles.first.latitude, 12.538354);
      expect(vehicles.first.longitude, 75.00226);
      expect(vehicles.first.ignition, isTrue);
      expect(vehicles.first.status.name, 'live');
    });

    test('wrong key returns [] — the device cannot be verified, so it errors', () async {
      final client = MockClient(
        (_) async => http.Response('[]', 200),
      );
      // Strict device matching cannot prove the entered vehicle
      // exists in an empty fleet, so this is a clear error (not a
      // silent empty list): the key is wrong or the device id is.
      await expectLater(
        RemoteProviderClient(entry).fetchLiveVehicles(
          const ProviderCredentials(deviceId: '10001', secret: 'wrong-key'),
          httpClient: client,
        ),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.message,
            'message',
            contains('found no vehicle'),
          ),
        ),
      );
    });

    test('a real IMEI matches the vehicle via its imei field', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode([
            {
              "VId": 10001,
              "VName": "BUS 01",
              "Imei": "860000000000001",
              "TTime": "2026-11-09T16:01:46",
              "Lat": "12.5383540",
              "Lon": "75.0022600",
              "Ign": true,
              "Spd": 0,
            },
          ]),
          200,
        ),
      );
      // Entering the IMEI (not the numeric VId) must still find the
      // vehicle — the old bug fetched /Vehicle?vehicleId=<imei> and
      // got "_Expired" instead.
      final vehicles = await RemoteProviderClient(entry).fetchLiveVehicles(
        const ProviderCredentials(
          deviceId: '860000000000001',
          secret: 'fake-key',
        ),
        httpClient: client,
      );
      expect(vehicles, hasLength(1));
      expect(vehicles.first.id, '10001');
    });

    test('an unknown device id does not match', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode([
            {
              "VId": 10001,
              "VName": "BUS 01",
              "Imei": "860000000000001",
              "TTime": "2026-11-09T16:01:46",
              "Lat": "12.5383540",
              "Lon": "75.0022600",
              "Ign": true,
              "Spd": 0,
            },
          ]),
          200,
        ),
      );
      await expectLater(
        RemoteProviderClient(entry).fetchLiveVehicles(
          const ProviderCredentials(
            deviceId: '860000000000099',
            secret: 'fake-key',
          ),
          httpClient: client,
        ),
        throwsA(isA<ProviderException>()),
      );
    });
  });

  group('RemoteProviderClient — Aargee shape', () {
    late RegistryEntry entry;

    setUp(() {
      entry = parseProviderRegistry('''
{
  "version": 1,
  "providers": [
    {"key": "aargee", "displayName": "Aargee GPS",
     "baseUrl": "https://rgvtrack.aargee.net/external/api/v2",
     "auth": {"style": "body", "bodyField": "apikey", "secretFormat": "key"},
     "authKind": "apiKey",
     "deviceIdLabel": "IMEI / Vehicle ID", "secretLabel": "API Key",
     "supportsHistory": true, "verified": true,
     "genericCompatible": true, "timeoutSeconds": 30,
     "fleet": {"method": "POST", "path": "/get_all_vehicles_last_data/",
               "body": {"apikey": "{secret}", "split_latlng": "True"}},
     "history": {"method": "POST", "path": "/get_vehicle_details/",
                 "body": {"apikey": "{secret}", "fromdate": "{from}",
                          "todate": "{to}", "vehicle_id": "{deviceId}"}},
     "historyDeviceParam": {"vehicleIdParam": "vehicle_id",
                            "imeiParam": "imei"},
     "listPath": "data", "locationField": "location",
     "successCheck": {"field": "status", "equals": 1},
     "fields": {"id": "vehicle", "displayName": "vehicle", "imei": "imei",
                "ignition": "ignition", "speed": "speed",
                "lastUpdated": "time",
                "trueValues": ["on", "true", "1"],
                "falseValues": ["off", "false", "0"]}}
  ]
}
''').entryFor('aargee')!;
    });

    test('POST with apikey in body, nested data, "lat lon" location', () async {
      Map<String, dynamic>? seenBody;
      final client = MockClient((request) async {
        seenBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            "status": 1,
            "data": [
              {
                "vehicle": "KL00XX0000",
                "imei": "860000000000001",
                "ignition": "on",
                "speed": 42,
                "location": "12.5383540 75.0022600",
                "time": "2026-11-11 16:23:00",
              },
            ],
          }),
          200,
        );
      });
      final vehicles = await RemoteProviderClient(entry).fetchLiveVehicles(
        const ProviderCredentials(deviceId: 'KL00XX0000', secret: 'fake-key'),
        httpClient: client,
      );
      expect(seenBody?['apikey'], 'fake-key');
      expect(seenBody?['split_latlng'], 'True');
      expect(vehicles, hasLength(1));
      expect(vehicles.first.id, 'KL00XX0000');
      expect(vehicles.first.latitude, 12.538354);
      expect(vehicles.first.longitude, 75.00226);
      expect(vehicles.first.ignition, isTrue);
      expect(vehicles.first.speedKmph, 42);
    });

    test('status != 1 is a ProviderException', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({"status": 2, "data": []}),
          200,
        ),
      );
      await expectLater(
        RemoteProviderClient(entry).fetchLiveVehicles(
          const ProviderCredentials(deviceId: 'KL00XX0000', secret: 'x'),
          httpClient: client,
        ),
        throwsA(isA<ProviderException>()),
      );
    });

    test('history uses the vehicle_id body field + date range', () async {
      Map<String, dynamic>? seenBody;
      final client = MockClient((request) async {
        seenBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            "status": 1,
            "data": [
              {
                "vehicle": "KL00XX0000",
                "imei": "860000000000001",
                "ignition": "on",
                "speed": 30,
                "location": "12.5383540 75.0022600",
                "time": "2026-11-11 09:00:00",
              },
            ],
          }),
          200,
        );
      });
      final history = await RemoteProviderClient(entry).fetchHistory(
        const ProviderCredentials(deviceId: 'KL00XX0000', secret: 'fake-key'),
        from: DateTime(2026, 11, 11),
        to: DateTime(2026, 11, 12),
        httpClient: client,
      );
      expect(seenBody?['vehicle_id'], 'KL00XX0000');
      expect(seenBody?['fromdate'], '2026-11-11 00:00:00');
      expect(seenBody?['todate'], '2026-11-12 00:00:00');
      expect(history, hasLength(1));
      expect(history.first.speedKmph, 30);
    });
  });
}
