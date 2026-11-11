import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/gps_provider.dart';
import '../../models/provider_credentials.dart';
import '../../models/vehicle.dart';
import '../../utils/parsing.dart';
import 'gps_provider_client.dart';

/// Aargee Compass API v2.5 client.
///
/// VERIFIED LIVE 2026-11-09.
/// - Base: https://rgvtrack.aargee.net/external/api/v2
/// - ALL requests are POST with a JSON body; the API key goes in the body
///   as `apikey` — no header auth.
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
/// 2026-11-09. UniTrack stores the raw string and displays it as-is;
/// do not convert timezones.
class AargeeClient extends GpsProviderClient {
  @override
  GpsProvider get provider => GpsProvider.aargee;

  static const _base = 'https://rgvtrack.aargee.net/external/api/v2';

  /// Throws a [ProviderException] unless the Aargee status code is 1.
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
    throw ProviderException('Aargee: $detail$extra');
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
        // Aargee's server is slow: 10.6s observed 2026-11-11 for a
        // last-data call, so 20s leaves little headroom on mobile data.
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw ProviderException('Aargee returned HTTP ${response.statusCode}.');
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
      return parseLastData(decoded);
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
  static List<Vehicle> parseVehicleList(Map<String, dynamic> decoded) {
    final data = decoded['data'] as List<dynamic>? ?? const [];
    return data.whereType<Map<String, dynamic>>().map((json) {
      final imei = json['imei']?.toString();
      final number = json['vehicle_number']?.toString();
      final id = json['vehicle_id']?.toString() ?? imei ?? 'unknown';
      return Vehicle(
        id: id,
        displayName: number ?? imei ?? id,
        providerKey: GpsProvider.aargee.key,
        imei: imei,
        rawJson: json,
      );
    }).toList();
  }

  /// Parses a decoded last-data / details response (status already
  /// checked). Public for tests.
  static List<Vehicle> parseLastData(Map<String, dynamic> decoded) {
    final data = decoded['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(parseLastDataItem)
        .toList();
  }

  /// Parses one last-data item, accepting both the `location` string
  /// ("`<lat> <lon>`") and the split_latlng latitude/longitude fields.
  /// Public for tests.
  static Vehicle parseLastDataItem(Map<String, dynamic> json) {
    double? lat;
    double? lon;
    if (json.containsKey('latitude') || json.containsKey('longitude')) {
      lat = parseCoord(json['latitude']);
      lon = parseCoord(json['longitude']);
    } else {
      final parts = (json['location'] ?? '').toString().trim().split(
        RegExp(r'\s+'),
      );
      if (parts.length >= 2) {
        lat = double.tryParse(parts[0]);
        lon = double.tryParse(parts[1]);
      }
    }
    final ignition = parseIgnition(json['ignition']);
    final imei = json['imei']?.toString();
    final name = json['vehicle']?.toString();
    final timeRaw = json['time']?.toString() ?? '';
    return Vehicle(
      id: imei ?? name ?? 'unknown',
      displayName: name ?? imei ?? 'Unknown vehicle',
      providerKey: GpsProvider.aargee.key,
      imei: imei,
      latitude: lat,
      longitude: lon,
      speedKmph: parseSpeed(json['speed']),
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
