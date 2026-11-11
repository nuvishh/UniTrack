import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/gps_provider.dart';
import '../../models/provider_credentials.dart';
import '../../models/vehicle.dart';
import '../../utils/parsing.dart';
import 'gps_provider_client.dart';

/// Voltysoft / SimplyTrack Pull API v12 client.
///
/// VERIFIED LIVE 2026-11-09.
/// - Base MUST be https://india.voltysoft.com/api/v12/ — plain http
///   returns HTTP 403 "You are not authorized".
/// - Every request needs the `x-api-key` header (without it requests are
///   blocked as malicious).
/// - GET /vehicles/{userId} → latest point for every vehicle.
/// - GET /vehicles/{userId}/{imei} → latest point for one vehicle.
/// - GET /vehicles/{userId}/{imei}/{fromEpoch}/{toEpoch} → track data
///   (epoch seconds) with direction + directionCardinal.
/// - Rate limit: 100 requests/hour — poll slowly (min 60s per account).
///
/// Credentials (see GPS guide, Option E):
/// - Option 1: secret = `userId:apiKey`, deviceId = 15-digit IMEI.
/// - Option 2: secret = API key, deviceId = `userId:imei`.
class SimplyTrackClient extends GpsProviderClient {
  @override
  GpsProvider get provider => GpsProvider.voltysoft;

  static const _base = 'https://india.voltysoft.com/api/v12';

  /// Splits the credentials into userId / apiKey / imei. Public for tests.
  static ({String userId, String apiKey, String? imei}) splitCredentials(
    ProviderCredentials credentials,
  ) {
    if (credentials.deviceId.contains(':')) {
      final parts = credentials.deviceId.split(':');
      return (
        userId: parts.first,
        apiKey: credentials.secret,
        imei: parts.sublist(1).join(':'),
      );
    }
    if (credentials.secret.contains(':')) {
      final parts = credentials.secret.split(':');
      return (
        userId: parts.first,
        apiKey: parts.sublist(1).join(':'),
        imei: credentials.deviceId,
      );
    }
    // A bare API key + a 15-digit IMEI as the device ID cannot work:
    // the user ID is missing, and the IMEI would be sent as the
    // userId in the URL. Fail fast with directions instead of a
    // cryptic HTTP error (same class of bug as HashTrace's IMEI/VId
    // mix-up, fixed 2026-11-11).
    final deviceId = credentials.deviceId.trim();
    if (deviceId.length == 15 && int.tryParse(deviceId) != null) {
      throw ProviderException(
        'SimplyTrack needs your user ID as well as the API key — '
        'enter the key as userId:apiKey, or the device ID as '
        'userId:imei.',
      );
    }
    return (
      userId: credentials.deviceId,
      apiKey: credentials.secret,
      imei: null,
    );
  }

  Future<http.Response> _get(
    String path,
    String apiKey,
    http.Client client,
  ) async {
    final response = await client
        .get(Uri.parse('$_base$path'), headers: {'x-api-key': apiKey})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 403) {
      throw ProviderException(
        'SimplyTrack rejected the request (HTTP 403). Check that the '
        'API key is valid and the request uses https.',
      );
    }
    if (response.statusCode != 200) {
      throw ProviderException(
        'SimplyTrack returned HTTP ${response.statusCode}.',
      );
    }
    return response;
  }

  @override
  Future<List<Vehicle>> fetchLiveVehicles(
    ProviderCredentials credentials, {
    http.Client? httpClient,
  }) async {
    final auth = splitCredentials(credentials);
    final client = httpClient ?? http.Client();
    try {
      final response = await _get(
        '/vehicles/${Uri.encodeComponent(auth.userId)}',
        auth.apiKey,
        client,
      );
      final vehicles = parseVehicleList(response.body);
      final imei = auth.imei;
      if (imei == null || imei.isEmpty) return vehicles;
      // The device IMEI was given — verify THAT vehicle exists under
      // this account instead of passing any vehicle as a success.
      final match = vehicles
          .where((v) => v.imei == imei || v.id == imei)
          .toList();
      if (match.isEmpty) {
        throw ProviderException(
          'SimplyTrack found no vehicle with IMEI "$imei" — check the '
          'device IMEI.',
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
    final auth = splitCredentials(credentials);
    final imei = auth.imei;
    if (imei == null || imei.isEmpty) {
      throw ProviderException(
        'SimplyTrack history needs a vehicle IMEI in the device ID.',
      );
    }
    final client = httpClient ?? http.Client();
    try {
      final fromEpoch = from.millisecondsSinceEpoch ~/ 1000;
      final toEpoch = to.millisecondsSinceEpoch ~/ 1000;
      final response = await _get(
        '/vehicles/${Uri.encodeComponent(auth.userId)}/'
        '${Uri.encodeComponent(imei)}/$fromEpoch/$toEpoch',
        auth.apiKey,
        client,
      );
      return parseVehicleList(response.body);
    } finally {
      if (httpClient == null) client.close();
    }
  }

  /// Parses a vehicle-list response (array, or a single object).
  /// Public for tests.
  static List<Vehicle> parseVehicleList(String body) {
    final decoded = jsonDecode(body);
    final List<dynamic> rawList;
    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map<String, dynamic>) {
      rawList = [decoded];
    } else {
      return const [];
    }
    return rawList.whereType<Map<String, dynamic>>().map(parseVehicle).toList();
  }

  /// Parses one vehicle object. Public for tests.
  static Vehicle parseVehicle(Map<String, dynamic> json) {
    final imei = json['imei']?.toString();
    final regNo = json['regno']?.toString();
    final engineOn = parseIgnition(json['engineOn']);
    final statusRaw = json['status']?.toString().toLowerCase();
    final VehicleStatus status;
    if (engineOn == true || statusRaw == 'moving') {
      status = VehicleStatus.live;
    } else if (statusRaw == 'stopped' || engineOn == false) {
      status = VehicleStatus.idle;
    } else {
      // 'Unreachable' and anything else: position may be stale.
      status = VehicleStatus.unknown;
    }
    final timeRaw = json['time']?.toString() ?? '';
    return Vehicle(
      id: imei ?? regNo ?? 'unknown',
      displayName: regNo ?? imei ?? 'Unknown vehicle',
      providerKey: GpsProvider.voltysoft.key,
      imei: imei,
      latitude: parseCoord(json['lat']),
      longitude: parseCoord(json['lon']),
      speedKmph: parseSpeed(json['speed']),
      ignition: engineOn,
      lastUpdatedRaw: timeRaw,
      lastUpdated: parseDateTime(timeRaw),
      status: status,
      rawJson: json,
    );
  }
}
