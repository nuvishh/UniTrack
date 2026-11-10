import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/gps_provider.dart';
import '../../models/provider_credentials.dart';
import '../../models/vehicle.dart';
import '../../utils/parsing.dart';
import 'gps_provider_client.dart';

/// HashTrace Tracker API client.
///
/// VERIFIED LIVE 2026-11-09.
/// - Base: https://cdn.hashtrace.com/api/Tracker/
/// - Auth is the `authKey` query parameter only — no headers.
/// - GET /All?authKey=... → JSON array of vehicle objects.
/// - GET /Vehicle?authKey=...&vehicleId=... → single vehicle object.
/// - Each object has 12 fields: VId, VName, Imei, VPlate, TTime, Lat,
///   Lon, Ign, Spd, Dir, MVolt, Batt. Lat/Lon are STRINGS, TTime has no
///   timezone.
///
/// Error behaviour (verified live — read the payload, not just the code):
/// - Missing authKey / vehicleId → HTTP 404.
/// - Wrong key → HTTP 200 + empty array [].
/// - Unknown / expired vehicleId → HTTP 200 + sentinel object
///   (VId 0, VName "_Expired", Lat/Lon "0.00") — the client MUST check
///   for it and never plot it.
///
/// Live snapshots only — no history support.
class HashTraceClient extends GpsProviderClient {
  @override
  GpsProvider get provider => GpsProvider.hashtrace;

  static const _base = 'https://cdn.hashtrace.com/api/Tracker';

  /// True when [json] is the "_Expired" sentinel record.
  static bool isExpiredSentinel(Map<String, dynamic> json) {
    final vId = json['VId'];
    final vName = json['VName']?.toString();
    return (vId is num && vId == 0) || vName == '_Expired';
  }

  @override
  Future<List<Vehicle>> fetchLiveVehicles(
    ProviderCredentials credentials, {
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? http.Client();
    try {
      // A numeric device id is a VId — fetch that vehicle directly.
      final vehicleId = int.tryParse(credentials.deviceId.trim());
      if (vehicleId != null) {
        final vehicle = await fetchVehicle(
          credentials.secret,
          vehicleId,
          httpClient: client,
        );
        return [vehicle];
      }
      final response = await client
          .get(
            Uri.parse(
              '$_base/All?authKey=${Uri.encodeQueryComponent(credentials.secret)}',
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) {
        throw ProviderException(
          'HashTrace returned HTTP 404 — check that the auth key is set.',
        );
      }
      if (response.statusCode != 200) {
        throw ProviderException(
          'HashTrace returned HTTP ${response.statusCode}.',
        );
      }
      return parseVehicleList(response.body);
    } finally {
      if (httpClient == null) client.close();
    }
  }

  /// Fetches one vehicle by its VId. Returns a vehicle with
  /// [VehicleStatus.expired] when the id is unknown/expired.
  Future<Vehicle> fetchVehicle(
    String authKey,
    int vehicleId, {
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? http.Client();
    try {
      final response = await client
          .get(
            Uri.parse(
              '$_base/Vehicle?authKey=${Uri.encodeQueryComponent(authKey)}'
              '&vehicleId=$vehicleId',
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) {
        throw ProviderException(
          'HashTrace returned HTTP 404 — check the auth key and vehicle ID.',
        );
      }
      if (response.statusCode != 200) {
        throw ProviderException(
          'HashTrace returned HTTP ${response.statusCode}.',
        );
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return parseVehicle(decoded);
    } finally {
      if (httpClient == null) client.close();
    }
  }

  @override
  Future<bool> testConnection(
    ProviderCredentials credentials, {
    http.Client? httpClient,
  }) async {
    final vehicles = await fetchLiveVehicles(
      credentials,
      httpClient: httpClient,
    );
    if (vehicles.isEmpty) {
      // A wrong key also returns an empty list — say so plainly.
      throw ProviderException(
        'HashTrace returned no vehicles. A wrong auth key also returns '
        'an empty list, so double-check the key.',
      );
    }
    if (vehicles.any((v) => v.status == VehicleStatus.expired)) {
      throw ProviderException(
        'HashTrace reports this vehicle as expired — check the vehicle ID.',
      );
    }
    return true;
  }

  /// Parses an /All response body. Sentinel records are skipped.
  /// Public for tests.
  static List<Vehicle> parseVehicleList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .where((json) => !isExpiredSentinel(json))
        .map(parseVehicle)
        .toList();
  }

  /// Parses one vehicle object. A sentinel record becomes a vehicle with
  /// status [VehicleStatus.expired] and no fix. Public for tests.
  static Vehicle parseVehicle(Map<String, dynamic> json) {
    if (isExpiredSentinel(json)) {
      return Vehicle(
        id: '0',
        displayName: '_Expired',
        providerKey: GpsProvider.hashtrace.key,
        lastUpdatedRaw: json['TTime']?.toString() ?? '',
        status: VehicleStatus.expired,
        rawJson: json,
      );
    }
    final ignition = parseIgnition(json['Ign']);
    final timeRaw = json['TTime']?.toString() ?? '';
    final vId = json['VId']?.toString() ?? 'unknown';
    final plate = json['VPlate']?.toString();
    final name = json['VName']?.toString();
    return Vehicle(
      id: vId,
      displayName: plate ?? name ?? vId,
      providerKey: GpsProvider.hashtrace.key,
      imei: json['Imei']?.toString(),
      latitude: parseCoord(json['Lat']),
      longitude: parseCoord(json['Lon']),
      speedKmph: parseSpeed(json['Spd']),
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
