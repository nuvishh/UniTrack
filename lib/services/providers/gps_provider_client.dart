import 'package:http/http.dart' as http;

import '../../models/gps_provider.dart';
import '../../models/provider_credentials.dart';
import '../../models/vehicle.dart';

/// Error thrown when a provider request fails or the provider reports an
/// error (bad key, rate limit, vehicle not assigned, ...). The [message]
/// is safe to show in the UI — it never contains a credential.
class ProviderException implements Exception {
  ProviderException(this.message);

  final String message;

  @override
  String toString() => 'ProviderException: $message';
}

/// Common interface every GPS provider client implements.
///
/// Clients are stateless: credentials are passed in per call, and an
/// optional [http.Client] can be injected (used by tests). When no client
/// is passed, the implementation creates and closes its own.
abstract class GpsProviderClient {
  /// The built-in provider this client serves, or null for a remote
  /// (registry-driven) client, which has no enum entry. Built-in
  /// clients override this; remote clients override [providerKey],
  /// [providerDisplayName], [supportsHistory] and
  /// [minimumPollInterval] instead.
  GpsProvider? get provider => null;

  /// Lowercase key, e.g. 'aargee'.
  String get providerKey => provider!.key;

  /// Display name, e.g. 'Aargee GPS'.
  String get providerDisplayName => provider!.displayName;

  bool get supportsHistory => provider?.supportsHistory ?? false;

  Duration get minimumPollInterval =>
      provider?.minPollInterval ?? const Duration(seconds: 60);

  /// Fetches the latest live snapshot for the account in [credentials].
  /// Returns every vehicle visible to that account (a fleet call where
  /// the provider supports one); the tracker de-duplicates by
  /// provider + vehicle id.
  Future<List<Vehicle>> fetchLiveVehicles(
    ProviderCredentials credentials, {
    http.Client? httpClient,
  });

  /// Fetches historical breadcrumb points for one vehicle between [from]
  /// and [to]. Throws [UnsupportedError] for providers that only return
  /// live snapshots (HashTrace, LiveTrace).
  Future<List<Vehicle>> fetchHistory(
    ProviderCredentials credentials, {
    required DateTime from,
    required DateTime to,
    http.Client? httpClient,
  }) {
    throw UnsupportedError(
      '$providerDisplayName does not support history — '
      'it returns live snapshots only.',
    );
  }

  /// Quick check used by the add-vehicle screen: true when the account
  /// returns at least one vehicle. Providers override this when an empty
  /// result can also mean a bad key (HashTrace).
  Future<bool> testConnection(
    ProviderCredentials credentials, {
    http.Client? httpClient,
  }) async {
    final vehicles = await fetchLiveVehicles(
      credentials,
      httpClient: httpClient,
    );
    return vehicles.isNotEmpty;
  }
}
