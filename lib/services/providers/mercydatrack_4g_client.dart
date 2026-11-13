import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/gps_provider.dart';
import '../../models/provider_credentials.dart';
import '../../models/vehicle.dart';
import '../../utils/parsing.dart';
import 'gps_provider_client.dart';
import 'mercydatrack_client.dart';

/// Mercydatrack client for 4G devices (proconsole).
///
/// VERIFIED LIVE 2026-11-12.
/// - Base: https://proconsole.mercydatrack.com/mtrack
///   (the 2G console is klconsole.mercydatrack.com — see
///   [MercyDataTrackClient] — same account login, different console
///   per device generation.)
/// - GET /vehicle-data?username=...&password=...&vehicle_registration=...
///   → {"status":"success","code":200,"data":{...}} — one vehicle
///   object with today's track.
/// - Data shape (DIFFERENT from the 2G /vehicle-live-data response):
///   data = {"date": "dd-MM-yyyy", "vehicle_registration": "...",
///   "data": [ {latitude, longitude, ignition ("ON"/"OFF"),
///   mainPower, sourceTime ("hh:mm:ss AM/PM"), speed}, ... ]} —
///   the points array is today's track, newest first. The live
///   position is the latest point by time. There is no imei_no,
///   serial_no or source_date field in this response.
/// - The vehicle_registration parameter selects one vehicle when the
///   account has several (verified live: same response with and
///   without it for a single-vehicle account).
///
/// Credentials in UniTrack: deviceId = vehicle registration number
/// (4G devices report the chassis number here), secret =
/// "username:password".
class MercyDataTrack4GClient extends GpsProviderClient {
  @override
  GpsProvider get provider => GpsProvider.mercydatrack4g;

  static const _base = 'https://proconsole.mercydatrack.com/mtrack';

  /// Base URL (live-verified 2026-11-12).
  static String get baseUrl => _base;

  @override
  Future<List<Vehicle>> fetchLiveVehicles(
    ProviderCredentials credentials, {
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? http.Client();
    try {
      final deviceId = credentials.deviceId.trim();
      final auth = MercyDataTrackClient.splitAuth(credentials);
      final uri = Uri.parse(
        '$_base/vehicle-data'
        '?username=${Uri.encodeQueryComponent(auth.username)}'
        '&password=${Uri.encodeQueryComponent(auth.password)}'
        '&vehicle_registration=${Uri.encodeQueryComponent(deviceId)}',
      );
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw ProviderException(
          'Mercydatrack (4G) returned HTTP ${response.statusCode}.',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw ProviderException(
          'Mercydatrack (4G) returned an unexpected response.',
        );
      }
      if (decoded['status'] != 'success') {
        throw ProviderException(
          'Mercydatrack (4G) reported an error — check the username, '
          'password and vehicle registration.',
        );
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw ProviderException(
          'Mercydatrack (4G) returned no vehicle data — check the '
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
          'Mercydatrack (4G) found no vehicle with registration '
          '"$deviceId" — check the vehicle registration number.',
        );
      }
      return [vehicle];
    } finally {
      if (httpClient == null) client.close();
    }
  }

  /// Parses one 4G vehicle-data object (date + registration + today's
  /// points). The live position is the latest point by time. Public
  /// for tests.
  static Vehicle parseVehicle(Map<String, dynamic> json) {
    final reg = json['vehicle_registration']?.toString() ?? 'unknown';
    final date = json['date']?.toString() ?? '';
    final points = json['data'];
    if (points is! List || points.isEmpty) {
      throw ProviderException(
        'Mercydatrack (4G) returned no points for vehicle "$reg".',
      );
    }
    // Points arrive newest-first, but pick the latest by parsed time
    // so the live position is right even if the order ever changes.
    Map<String, dynamic>? latest;
    DateTime? latestTime;
    for (final point in points) {
      if (point is! Map<String, dynamic>) continue;
      final time = parseDayMonthYearTime(
        '$date ${point['sourceTime']?.toString() ?? ''}',
      );
      if (latest == null ||
          (time != null &&
              (latestTime == null || time.isAfter(latestTime)))) {
        latest = point;
        latestTime = time;
      }
    }
    if (latest == null) {
      throw ProviderException(
        'Mercydatrack (4G) returned no usable points for vehicle '
        '"$reg".',
      );
    }
    final ignition = parseIgnition(latest['ignition']);
    final timeRaw = latestTime != null
        ? '$date ${latest['sourceTime']?.toString() ?? ''}'
        : '';
    return Vehicle(
      id: reg,
      displayName: reg,
      providerKey: GpsProvider.mercydatrack4g.key,
      imei: null,
      latitude: parseCoord(latest['latitude']),
      longitude: parseCoord(latest['longitude']),
      speedKmph: parseSpeed(latest['speed']),
      ignition: ignition,
      lastUpdatedRaw: timeRaw,
      lastUpdated: latestTime,
      status: ignition == true
          ? VehicleStatus.live
          : ignition == false
              ? VehicleStatus.idle
              : VehicleStatus.unknown,
      rawJson: json,
    );
  }
}
