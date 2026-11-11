import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/gps_provider.dart';
import '../../models/provider_credentials.dart';
import '../../models/vehicle.dart';
import 'aargee_client.dart';
import 'gps_provider_client.dart';

/// Transight Compass API v2.5 client.
///
/// VERIFIED LIVE 2026-11-11.
/// - Base: https://compass.transight.in/external/api/v2
///   (Discovery base https://discovery.transight.in/external/api/v2
///   exists in the vendor doc but was not tested — Compass is the one
///   the live key works against.)
/// - ALL requests are POST with a JSON body; the API key goes in the body
///   as `apikey` — no header auth. Same contract as [AargeeClient]
///   (same Compass v2.5 platform): the parsers below reuse Aargee's and
///   rewrite the provider key to Transight.
/// - POST /get_all_vehicles/ {"apikey": ...} → {status: 1,
///   data: [{vehicle_number, vehicle_id, imei}]} — 100/day, do NOT poll.
/// - POST /get_all_vehicles_last_data/ {"apikey": ...} → {status: 1,
///   data: [{vehicle, imei, ignition, speed, location: "`<lat> <lon>`",
///   time}]} — 500/day, use this for polling.
/// - POST /get_vehicle_last_data/ {"apikey": ..., "vehicle_id": ...}
///   (or "imei": ...) — 500/day/vehicle.
/// - POST /get_vehicle_details/ {"apikey": ..., "vehicle_id": ...,
///   "fromdate": "yyyy-MM-dd HH:mm:ss", "todate": ...} → history with
///   meta pagination — 10/day/vehicle.
/// - Optional split_latlng: "True" returns latitude/longitude fields
///   instead of the single "location" string.
/// - Status codes: 0 server error, 1 success, 2 key not active,
///   3 vehicle not assigned, 4 rate limit reached, 5 data not available.
///
/// NOTE: the doc says `time` is UTC, but live values matched IST on
/// 2026-11-11 (same as Aargee). UniTrack stores the raw string and
/// displays it as-is; do not convert timezones.
class TransightClient extends GpsProviderClient {
  @override
  GpsProvider get provider => GpsProvider.transight;

  static const _base = 'https://compass.transight.in/external/api/v2';

  /// Throws a [ProviderException] unless the Transight status code is 1.
  /// Public for tests.
  static void checkStatus(Map<String, dynamic> json) {
    if (json['status'] == 1) return;
    const messages = {
      0: 'Server error',
      2: 'API key is not active — contact the administrator',
      3: 'Requested vehicle is not assigned to your account',
      4: 'API request limit reached — try again later',
      5: 'Data not available',
    };
    final status = json['status'];
    final detail = messages[status] ?? 'Unknown error (status $status)';
    final apiMessages = json['messages'];
    final extra = apiMessages is List && apiMessages.isNotEmpty
        ? ': ${apiMessages.join(', ')}'
        : '';
    throw ProviderException('Transight: $detail$extra');
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
    http.Client client,
  ) async {
    final response = await client
        .post(
          Uri.parse('$_base$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        // Same slow-server headroom as Aargee (30s).
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw ProviderException(
        'Transight returned HTTP ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    checkStatus(decoded);
    return decoded;
  }

  /// Lists all vehicles on the account (100/day — call rarely, never in
  /// the poll loop).
  Future<List<Vehicle>> fetchVehicleList(
    String apiKey, {
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? http.Client();
    try {
      final decoded = await _post('/get_all_vehicles/', {
        'apikey': apiKey,
      }, client);
      return parseVehicleList(decoded);
    } finally {
      if (httpClient == null) client.close();
    }
  }

  @override
  Future<List<Vehicle>> fetchLiveVehicles(
    ProviderCredentials credentials, {
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? http.Client();
    try {
      final decoded = await _post('/get_all_vehicles_last_data/', {
        'apikey': credentials.secret,
        'split_latlng': 'True',
      }, client);
      final vehicles = parseLastData(decoded);
      final deviceId = credentials.deviceId.trim();
      if (deviceId.isEmpty) return vehicles;
      // The device ID names one vehicle (numeric vehicle_id or
      // 15-digit IMEI) — verify THAT vehicle is in this account
      // instead of passing any vehicle as a success. (Same
      // device-matching rule as HashTrace, 2026-11-11.) The last-data
      // items carry no vehicle_id field in the parser, so match the
      // raw value too when the API returns one.
      final match = vehicles
          .where((v) =>
              v.id == deviceId ||
              v.imei == deviceId ||
              v.displayName == deviceId ||
              v.rawJson['vehicle_id']?.toString() == deviceId)
          .toList();
      if (match.isEmpty) {
        throw ProviderException(
          'Transight found no vehicle with ID "$deviceId" — check the '
          'vehicle ID (15-digit IMEI or numeric vehicle ID).',
        );
      }
      return match;
    } finally {
      if (httpClient == null) client.close();
    }
  }

  @override
  Future<List<Vehicle>> fetchHistory(
    ProviderCredentials credentials, {
    required DateTime from,
    required DateTime to,
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? http.Client();
    try {
      final body = <String, dynamic>{
        'apikey': credentials.secret,
        'fromdate': _formatDate(from),
        'todate': _formatDate(to),
        'split_latlng': 'True',
      };
      final deviceId = credentials.deviceId.trim();
      if (deviceId.length < 10 && int.tryParse(deviceId) != null) {
        body['vehicle_id'] = deviceId;
      } else {
        body['imei'] = deviceId;
      }
      final decoded = await _post('/get_vehicle_details/', body, client);
      return parseLastData(decoded);
    } finally {
      if (httpClient == null) client.close();
    }
  }

  static String _formatDate(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  /// Parses a decoded /get_all_vehicles/ response (status already
  /// checked). Vehicles have no live fix — use for listing only.
  /// Public for tests.
  static List<Vehicle> parseVehicleList(Map<String, dynamic> decoded) =>
      AargeeClient.parseVehicleList(decoded)
          .map((v) => v.copyWith(providerKey: GpsProvider.transight.key))
          .toList();

  /// Parses a decoded last-data / details response (status already
  /// checked). Public for tests.
  static List<Vehicle> parseLastData(Map<String, dynamic> decoded) =>
      AargeeClient.parseLastData(decoded)
          .map((v) => v.copyWith(providerKey: GpsProvider.transight.key))
          .toList();

  /// Parses one last-data item, accepting both the `location` string
  /// ("`<lat> <lon>`") and the split_latlng latitude/longitude fields.
  /// Public for tests.
  static Vehicle parseLastDataItem(Map<String, dynamic> json) =>
      AargeeClient.parseLastDataItem(json)
          .copyWith(providerKey: GpsProvider.transight.key);
}
