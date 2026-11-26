import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/gps_provider.dart';
import '../../models/provider_credentials.dart';
import '../../models/vehicle.dart';
import '../../utils/parsing.dart';
import 'gps_provider_client.dart';

/// AVLView (fleet.avlview.com) Developer API v3.1 client.
///
/// VERIFIED LIVE 2026-11-26.
/// - Base: https://fleet.avlview.com/open-api
/// - Auth: the `X-API-Key` header on every request. The key is the
///   account's API key, entered by the user in the add-vehicle form
///   and stored in secure storage — it is never hardcoded here.
/// - GET /v3.1/vehicles → [{vehicleId (int), plateId (uuid),
///   plateNumber, vehicleName, imei, ...}] — the fleet list.
/// - GET /v3.1/vehicleStatus → [{vehicleId (uuid), vehId (int),
///   imei, plateNumber, dateTime "yyyy-MM-dd HH:mm:ss",
///   status M/S/D (Moving/Stopped/Disconnected), latitude,
///   longitude, speed, ignition Y/N/U, odometer, ...}] — the live
///   fleet snapshot; use this for polling.
/// - GET /v3.1/vehicleRawData?plateCode={plateId uuid}
///   &fromDate={yyyy-MM-dd}&toDate={yyyy-MM-dd} → {status: 200,
///   vehiclerRawDetail: [{latitude, longitude, dateTime, speed,
///   ignitionOn Y/N, status MOVING/STOPPED, plateNo, plateId, ...}]}
///   — breadcrumb history. Note the misspelt `vehiclerRawDetail`
///   key, and that plateCode wants the plateId UUID: the plate
///   number ("KL 13 AD 8772", with or without spaces) 404s.
/// - GET /v3.1/trips?vehicleIds={uuid}&from={yyyy-MM-dd HH:mm:ss}
///   &to={...} → trip summaries (not breadcrumbs; not used here —
///   history uses vehicleRawData).
/// - Daily allowance: 25,000 calls/day shared across all endpoints
///   (per the API info page). Polling every 60s is ~1,440/day.
/// - History is date-based: a from/to window is fetched as whole
///   days, then filtered to the exact window client-side.
/// - The server is slow on big history payloads (one day of raw data
///   is ~1.7 MB / ~2,600 points), so all calls use a 30s timeout
///   like Aargee's.
class AvlViewClient extends GpsProviderClient {
  @override
  GpsProvider get provider => GpsProvider.avlview;

  static const _base = 'https://fleet.avlview.com/open-api';

  Future<dynamic> _get(
    String path,
    String apiKey,
    http.Client client, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse(
      '$_base$path',
    ).replace(queryParameters: query ?? const {});
    final response = await client
        .get(uri, headers: {'X-API-Key': apiKey, 'Accept': 'application/json'})
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw ProviderException(
        'AVLView: invalid API key — check the key entered for this '
        'account.',
      );
    }
    if (response.statusCode == 429) {
      throw ProviderException(
        'AVLView: daily call allowance reached — try again later.',
      );
    }
    if (response.statusCode != 200) {
      throw ProviderException(
        'AVLView returned HTTP ${response.statusCode}.',
      );
    }
    return jsonDecode(response.body);
  }

  /// Lists all vehicles on the account. Use for the add-vehicle
  /// flow and to resolve a plate number / IMEI to its plateId.
  Future<List<Vehicle>> fetchVehicleList(
    String apiKey, {
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? http.Client();
    try {
      final decoded = await _get('/v3.1/vehicles', apiKey, client);
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
      final decoded = await _get(
        '/v3.1/vehicleStatus',
        credentials.secret,
        client,
      );
      final vehicles = parseStatusList(decoded);
      final deviceId = credentials.deviceId.trim();
      if (deviceId.isEmpty) return vehicles;
      // The device ID names one vehicle — plate number, IMEI,
      // numeric vehId, or the plateId UUID. Verify THAT vehicle is
      // in this account instead of passing any vehicle as a success.
      // (Same device-matching rule as Aargee/HashTrace, 2026-11-11.)
      final match = vehicles
          .where(
            (v) =>
                v.id == deviceId ||
                v.imei == deviceId ||
                v.displayName == deviceId ||
                normalizeRegNo(v.displayName) ==
                    normalizeRegNo(deviceId) ||
                v.rawJson['vehId']?.toString() == deviceId,
          )
          .toList();
      if (match.isEmpty) {
        throw ProviderException(
          'AVLView found no vehicle "$deviceId" — check the plate '
          'number, IMEI, or plate ID.',
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
      final plateId = await _resolvePlateId(
        credentials.secret,
        credentials.deviceId.trim(),
        client,
      );
      final decoded = await _get(
        '/v3.1/vehicleRawData',
        credentials.secret,
        client,
        query: {
          'plateCode': plateId,
          'fromDate': _formatDate(from),
          'toDate': _formatDate(to),
        },
      );
      final points = parseRawData(decoded);
      // vehicleRawData returns whole days; keep only points inside
      // the requested window.
      return points.where((v) {
        final t = v.lastUpdated;
        if (t == null) return true;
        return !t.isBefore(from) && !t.isAfter(to);
      }).toList();
    } finally {
      if (httpClient == null) client.close();
    }
  }

  /// Resolves the device ID the user entered to the plateId UUID
  /// that vehicleRawData wants as plateCode.
  ///
  /// A UUID passes through as-is; anything else (plate number,
  /// IMEI, numeric vehId) is looked up in the fleet list. Throws
  /// [ProviderException] when the vehicle is not on this account.
  Future<String> _resolvePlateId(
    String apiKey,
    String deviceId,
    http.Client client,
  ) async {
    if (_isUuid(deviceId)) return deviceId;
    final decoded = await _get('/v3.1/vehicles', apiKey, client);
    final vehicles = parseVehicleList(decoded);
    final match = vehicles
        .where(
          (v) =>
              normalizeRegNo(v.displayName) == normalizeRegNo(deviceId) ||
              v.imei == deviceId ||
              v.rawJson['vehicleId']?.toString() == deviceId,
        )
        .toList();
    if (match.isEmpty) {
      throw ProviderException(
        'AVLView found no vehicle "$deviceId" — check the plate '
        'number, IMEI, or plate ID.',
      );
    }
    return match.first.id;
  }

  static bool _isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value.trim());

  static String _formatDate(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  /// Parses a decoded /v3.1/vehicles response. The response is a bare
  /// JSON array of VehicleProfile objects. Public for tests.
  static List<Vehicle> parseVehicleList(dynamic decoded) {
    final data = decoded is List ? decoded : const [];
    return data.whereType<Map<String, dynamic>>().map((json) {
      final plateId = json['plateId']?.toString();
      final vehicleId = json['vehicleId']?.toString();
      final number = json['plateNumber']?.toString();
      final name = json['vehicleName']?.toString();
      final id = plateId ?? vehicleId ?? number ?? 'unknown';
      return Vehicle(
        id: id,
        displayName: number ?? name ?? id,
        providerKey: GpsProvider.avlview.key,
        imei: json['imei']?.toString(),
        rawJson: json,
      );
    }).toList();
  }

  /// Parses a decoded /v3.1/vehicleStatus response (a bare JSON
  /// array of VehicleSnapshot objects). Public for tests.
  static List<Vehicle> parseStatusList(dynamic decoded) {
    final data = decoded is List ? decoded : const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(parseStatusItem)
        .toList();
  }

  /// Parses one vehicleStatus snapshot. Status M = moving, S =
  /// stopped, D = disconnected. Ignition is Y/N/U.
  /// Public for tests.
  static Vehicle parseStatusItem(Map<String, dynamic> json) {
    final lat = parseCoord(json['latitude']);
    final lon = parseCoord(json['longitude']);
    final ignition = _parseYesNo(json['ignition']);
    final imei = json['imei']?.toString();
    final plateId = json['vehicleId']?.toString();
    final vehId = json['vehId']?.toString();
    final plate = json['plateNumber']?.toString();
    final name = json['vehicleName']?.toString();
    final status = json['status']?.toString().toUpperCase();
    final timeRaw = json['dateTime']?.toString() ?? '';
    return Vehicle(
      id: plateId ?? vehId ?? imei ?? plate ?? 'unknown',
      displayName: plate ?? name ?? imei ?? 'Unknown vehicle',
      providerKey: GpsProvider.avlview.key,
      imei: imei,
      latitude: lat,
      longitude: lon,
      speedKmph: parseSpeed(json['speed']),
      ignition: ignition,
      lastUpdatedRaw: timeRaw,
      lastUpdated: parseDateTime(timeRaw),
      status: status == 'M'
          ? VehicleStatus.live
          : status == 'S'
          ? VehicleStatus.idle
          : VehicleStatus.unknown,
      rawJson: json,
    );
  }

  /// Parses a decoded /v3.1/vehicleRawData response: either the
  /// wrapped object {status: 200, vehiclerRawDetail: [...]} (note
  /// the misspelling) or a bare array. Public for tests.
  static List<Vehicle> parseRawData(dynamic decoded) {
    final List<dynamic> data;
    if (decoded is Map<String, dynamic>) {
      final wrapped = decoded['vehiclerRawDetail'];
      data = wrapped is List ? wrapped : const [];
    } else if (decoded is List) {
      data = decoded;
    } else {
      data = const [];
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(parseRawDataItem)
        .toList();
  }

  /// Parses one raw-data breadcrumb point. Status MOVING/STOPPED;
  /// ignitionOn Y/N. Public for tests.
  static Vehicle parseRawDataItem(Map<String, dynamic> json) {
    final lat = parseCoord(json['latitude']);
    final lon = parseCoord(json['longitude']);
    final ignition = _parseYesNo(json['ignitionOn']);
    final imei = json['imeiNumber']?.toString();
    final plateId = json['plateId']?.toString();
    final plate = json['plateNo']?.toString();
    final name = json['vehicleName']?.toString();
    final status = json['status']?.toString().toUpperCase();
    final timeRaw = json['dateTime']?.toString() ?? '';
    return Vehicle(
      id: plateId ?? plate ?? imei ?? 'unknown',
      displayName: plate ?? name ?? imei ?? 'Unknown vehicle',
      providerKey: GpsProvider.avlview.key,
      imei: imei,
      latitude: lat,
      longitude: lon,
      speedKmph: parseSpeed(json['speed']),
      ignition: ignition,
      lastUpdatedRaw: timeRaw,
      lastUpdated: parseDateTime(timeRaw),
      status: status == 'MOVING'
          ? VehicleStatus.live
          : status == 'STOPPED' || status == 'IDLE'
          ? VehicleStatus.idle
          : VehicleStatus.unknown,
      rawJson: json,
    );
  }

  /// Parses a Y/N/U (or yes/no) value. [parseIgnition] does not
  /// know Y/N, so AVLView maps it here.
  static bool? _parseYesNo(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final v = value.trim().toUpperCase();
      if (v == 'Y' || v == 'YES') return true;
      if (v == 'N' || v == 'NO') return false;
      if (v == 'U' || v == 'UNKNOWN') return null;
    }
    return parseIgnition(value);
  }
}
