import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/gps_provider.dart';
import '../../models/provider_credentials.dart';
import '../../models/vehicle.dart';
import '../../utils/parsing.dart';
import 'gps_provider_client.dart';

/// Radiant / LiveTrace client.
///
/// VERIFIED LIVE 2026-11-09.
/// - POST http://livetrace.live:1234/Live_All
/// - Header: Content-Type: application/json
/// - Body: {"header":{"Version":"1.0","clientName":"API_LiveTrace"},
///          "request":{"userid":"`<userid>`","key":"`<key>`"}}
/// - Response: {"response":{"LiveData":[{Lat, Lon, Speed, Time, Igni,
///   Nick, Reg_No, imei}, ...]}}
///
/// Credentials (see GPS guide, Option D):
/// - Option 1: deviceId = IMEI, secret = `userid:key`.
/// - Option 2: deviceId = user id, secret = key.
/// Vehicles are matched by imei, Reg_No, or Nick.
///
/// Live snapshots only — no history support.
class LiveTraceClient extends GpsProviderClient {
  @override
  GpsProvider get provider => GpsProvider.radiant;

  static const _url = 'http://livetrace.live:1234/Live_All';

  /// Splits the credentials into the userid/key pair the API wants.
  /// Public so it can be unit-tested.
  static ({String userId, String key}) splitAuth(
    ProviderCredentials credentials,
  ) {
    if (credentials.secret.contains(':')) {
      final parts = credentials.secret.split(':');
      return (userId: parts.first, key: parts.sublist(1).join(':'));
    }
    return (userId: credentials.deviceId, key: credentials.secret);
  }

  @override
  Future<List<Vehicle>> fetchLiveVehicles(
    ProviderCredentials credentials, {
    http.Client? httpClient,
  }) async {
    final auth = splitAuth(credentials);
    final client = httpClient ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse(_url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'header': {'Version': '1.0', 'clientName': 'API_LiveTrace'},
              'request': {'userid': auth.userId, 'key': auth.key},
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw ProviderException(
          'LiveTrace returned HTTP ${response.statusCode}.',
        );
      }
      final vehicles = parseLiveData(response.body);
      final deviceId = credentials.deviceId.trim();
      // Option 1 only (the secret holds userid:key, so the device ID
      // names one vehicle — IMEI, reg. no. or nick). In Option 2 the
      // device ID IS the user id, and the whole fleet is the right
      // result — so only filter when the id differs from the user id.
      // (Same device-matching rule as HashTrace, 2026-11-11.)
      if (deviceId.isEmpty || deviceId == auth.userId) return vehicles;
      final match = vehicles
          .where((v) =>
              v.id == deviceId ||
              v.imei == deviceId ||
              v.displayName == deviceId ||
              v.rawJson['Nick']?.toString() == deviceId ||
              v.rawJson['Reg_No']?.toString() == deviceId)
          .toList();
      if (match.isEmpty) {
        throw ProviderException(
          'LiveTrace found no vehicle with ID "$deviceId" — check the '
          'device IMEI, reg. no. or nick.',
        );
      }
      return match;
    } finally {
      if (httpClient == null) client.close();
    }
  }

  /// Parses a Live_All response body into [Vehicle]s. Public for tests.
  static List<Vehicle> parseLiveData(String body) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final response = decoded['response'];
    final rawList =
        (response is Map ? response['LiveData'] : null) as List<dynamic>? ??
        const [];
    return rawList.whereType<Map<String, dynamic>>().map(parseVehicle).toList();
  }

  /// Parses one LiveData entry. Public for tests.
  static Vehicle parseVehicle(Map<String, dynamic> json) {
    final imei = json['imei']?.toString();
    final regNo = json['Reg_No']?.toString();
    final nick = json['Nick']?.toString();
    final ignition = parseIgnition(json['Igni']);
    final timeRaw = json['Time']?.toString() ?? '';
    return Vehicle(
      id: imei ?? regNo ?? nick ?? 'unknown',
      displayName: regNo ?? nick ?? imei ?? 'Unknown vehicle',
      providerKey: GpsProvider.radiant.key,
      imei: imei,
      latitude: parseCoord(json['Lat']),
      longitude: parseCoord(json['Lon']),
      speedKmph: parseSpeed(json['Speed']),
      ignition: ignition,
      lastUpdatedRaw: timeRaw,
      lastUpdated: parseDateTime(timeRaw),
      status: ignition == true
          ? VehicleStatus.live
          : ignition == false
          ? VehicleStatus.idle
          : VehicleStatus.unknown,
      rawJson: json,
    );
  }
}
