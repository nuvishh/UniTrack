import 'package:http/http.dart' as http;

import '../../models/gps_provider.dart';
import '../../models/provider_credentials.dart';
import '../../models/vehicle.dart';
import 'gps_provider_client.dart';

/// PauldeaTrack client — GUIDE-ONLY, NOT live-verified.
///
/// Same pattern as MercyDataTrack: the GPS guide gives the console API
/// base URL https://console.pauldeatrack.com/ptrack/ and the auth pattern
/// (account username in `gps_device_id`, account password in
/// `gps_password`, vehicle matched by exact registration number in
/// `vehicle_no`) — but NO endpoint paths. This client is a skeleton.
///
/// TODO: confirm the endpoint paths against the PauldeaTrack console API
/// docs (the CampusMan backend calls a `vehicle-data` operation for
/// history), then implement fetchLiveVehicles/fetchHistory and set
/// `GpsProvider.pauldeatrack.verified` to true.
class PauldeaTrackClient extends GpsProviderClient {
  @override
  GpsProvider get provider => GpsProvider.pauldeatrack;

  static const _base = 'https://console.pauldeatrack.com/ptrack';

  /// Base URL from the GPS guide (endpoint paths still to confirm).
  static String get baseUrl => _base;

  @override
  Future<List<Vehicle>> fetchLiveVehicles(
    ProviderCredentials credentials, {
    http.Client? httpClient,
  }) async {
    throw ProviderException(
      'PauldeaTrack endpoint paths are not documented in the GPS guide '
      '— only the base URL ($_base) is known. Confirm the paths against '
      'the PauldeaTrack console API docs before enabling this provider.',
    );
  }
}
