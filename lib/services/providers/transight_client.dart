import 'package:http/http.dart' as http;

import '../../models/gps_provider.dart';
import '../../models/provider_credentials.dart';
import '../../models/vehicle.dart';
import 'aargee_client.dart';
import 'gps_provider_client.dart';

/// Transight GPS client — GUIDE-ONLY, NOT live-verified.
///
/// The GPS guide says Transight uses REST API v2 at
/// https://compass.transight.in/ with a 36-character API key and the same
/// IMEI / vehicle-ID identification as Aargee. It is a "Compass" v2
/// platform like Aargee, so the response shape is expected to match
/// [AargeeClient] — but the exact endpoint paths are NOT in the guide and
/// were never tested live, so this client deliberately does NOT call any
/// endpoint yet.
///
/// TODO: confirm the endpoint paths against the Transight API docs
/// (expected shape: POST `<base>`/external/api/v2/get_all_vehicles_last_data/
/// with {"apikey": ...} — UNVERIFIED, do not assume it), then replace
/// [fetchLiveVehicles] with a real call and set
/// `GpsProvider.transight.verified` to true.
class TransightClient extends GpsProviderClient {
  @override
  GpsProvider get provider => GpsProvider.transight;

  static const _base = 'https://compass.transight.in';

  /// Base URL from the GPS guide (endpoint paths still to confirm).
  static String get baseUrl => _base;

  @override
  Future<List<Vehicle>> fetchLiveVehicles(
    ProviderCredentials credentials, {
    http.Client? httpClient,
  }) async {
    throw ProviderException(
      'Transight endpoints are not verified yet — the GPS guide only '
      'gives the base URL ($_base). Confirm the endpoint paths against '
      'the Transight API docs before enabling this provider.',
    );
  }

  /// Parses an Aargee-shaped last-data response. Reuse this once the
  /// Transight endpoint paths are confirmed — the two platforms share
  /// the Compass v2 response format. The provider key is rewritten to
  /// Transight so parsed vehicles are never mislabelled as Aargee.
  static List<Vehicle> parseLastData(Map<String, dynamic> decoded) =>
      AargeeClient.parseLastData(decoded)
          .map((v) => v.copyWith(providerKey: GpsProvider.transight.key))
          .toList();
}
