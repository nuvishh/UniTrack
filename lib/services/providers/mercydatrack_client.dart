import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/gps_provider.dart';
import '../../models/provider_credentials.dart';
import '../../models/vehicle.dart';
import '../../utils/parsing.dart';
import 'gps_provider_client.dart';

/// Mercydatrack client.
///
/// VERIFIED LIVE 2026-11-11.
/// - Base: https://klconsole.mercydatrack.com/mtrack
/// - GET /vehicle-live-data?username=...&password=...&vehicle_registration=...
///   → {"status":"success","code":200,"data":{...}} — one vehicle object.
/// - Data fields: vehicle_registration, imei_no, latitude, longitude,
///   ignition ("ON"/"OFF"), speed, serial_no, source_date
///   ("dd-MM-yyyy hh:mm:ss AM/PM", no timezone).
/// - The vehicle_registration parameter selects one vehicle when the
///   account has several; the response carries that one vehicle only.
///
/// Credentials in UniTrack: deviceId = vehicle registration number,
/// secret = "username:password".
class MercyDataTrackClient extends GpsProviderClient {
  @override
  GpsProvider get provider => GpsProvider.mercydatrack;

  static const _base = 'https://klconsole.mercydatrack.com/mtrack';

  /// Base URL (live-verified 2026-11-11).
  static String get baseUrl => _base;

  /// Splits a "username:password" secret at the first colon.
  static ({String username, String password}) splitAuth(
    ProviderCredentials credentials,
  ) {
    final secret = credentials.secret.trim();
    final colon = secret.indexOf(':');
    if (colon <= 0 || colon == secret.length - 1) {
      throw ProviderException(
        'Mercydatrack needs the login as username:password — '
        'put the account username, a colon, then the password in the '
        'secret field.',
      );
    }
    return (
      username: secret.substring(0, colon),
      password: secret.substring(colon + 1),
    );
  }

  @override
  Future<List<Vehicle>> fetchLiveVehicles(
    ProviderCredentials credentials, {
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? http.Client();
    try {
      final deviceId = credentials.deviceId.trim();
      final auth = splitAuth(credentials);
      final uri = Uri.parse(
        '$_base/vehicle-live-data'
        '?username=${Uri.encodeQueryComponent(auth.username)}'
        '&password=${Uri.encodeQueryComponent(auth.password)}'
        '&vehicle_registration=${Uri.encodeQueryComponent(deviceId)}',
      );
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw ProviderException(
          'Mercydatrack returned HTTP ${response.statusCode}.',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw ProviderException(
          'Mercydatrack returned an unexpected response.',
        );
      }
      if (decoded['status'] != 'success') {
        throw ProviderException(
          'Mercydatrack reported an error — check the username, '
          'password and vehicle registration.',
        );
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw ProviderException(
          'Mercydatrack returned no vehicle data — check the '
          'vehicle registration.',
        );
      }
      final vehicle = parseVehicle(data);
      // The API selects by vehicle_registration, but verify the
      // returned vehicle is the one asked for — the test must prove
      // THAT vehicle exists, not just that the login works.
      if (deviceId.isNotEmpty &&
          normalizeRegNo(vehicle.displayName) != normalizeRegNo(deviceId)) {
        throw ProviderException(
          'Mercydatrack found no vehicle with registration '
          '"$deviceId" — check the vehicle registration number.',
        );
      }
      return [vehicle];
    } finally {
      if (httpClient == null) client.close();
    }
  }

  /// Parses one vehicle-live-data object. Public for tests.
  static Vehicle parseVehicle(Map<String, dynamic> json) {
    final reg = json['vehicle_registration']?.toString() ?? 'unknown';
    final ignition = parseIgnition(json['ignition']);
    final timeRaw = json['source_date']?.toString() ?? '';
    return Vehicle(
      id: reg,
      displayName: reg,
      providerKey: GpsProvider.mercydatrack.key,
      imei: json['imei_no']?.toString(),
      latitude: parseCoord(json['latitude']),
      longitude: parseCoord(json['longitude']),
      speedKmph: parseSpeed(json['speed']),
      ignition: ignition,
      lastUpdatedRaw: timeRaw,
      lastUpdated: parseDayMonthYearTime(timeRaw),
      status: ignition == true
          ? VehicleStatus.live
          : ignition == false
              ? VehicleStatus.idle
              : VehicleStatus.unknown,
      rawJson: json,
    );
  }
}
