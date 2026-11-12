import '../../models/gps_provider.dart';
import '../../models/provider_registry.dart';
import 'aargee_client.dart';
import 'gps_provider_client.dart';
import 'hashtrace_client.dart';
import 'livetrace_client.dart';
import 'mercydatrack_4g_client.dart';
import 'mercydatrack_client.dart';
import 'pauldeatrack_client.dart';
import 'remote_provider_client.dart';
import 'simplytrack_client.dart';
import 'transight_client.dart';

/// Returns the client for a provider.
GpsProviderClient clientFor(GpsProvider provider) {
  switch (provider) {
    case GpsProvider.transight:
      return TransightClient();
    case GpsProvider.aargee:
      return AargeeClient();
    case GpsProvider.radiant:
      return LiveTraceClient();
    case GpsProvider.mercydatrack:
      return MercyDataTrackClient();
    case GpsProvider.mercydatrack4g:
      return MercyDataTrack4GClient();
    case GpsProvider.pauldeatrack:
      return PauldeaTrackClient();
    case GpsProvider.voltysoft:
      return SimplyTrackClient();
    case GpsProvider.hashtrace:
      return HashTraceClient();
  }
}

/// Returns the client for a lowercase provider key
/// (e.g. 'aargee', 'hashtrace'). Throws [ArgumentError] for unknown keys.
GpsProviderClient clientForKey(String key) =>
    clientFor(GpsProvider.fromKey(key));

/// Returns the client for a saved vehicle, registry-aware.
///
/// Resolution order (see providers/README.md):
/// 1. A registry override for a built-in key — only when the entry is
///    marked `overrideBuiltin` + `genericCompatible` with an https
///    base URL. Anything else falls through.
/// 2. The built-in client for the 7 shipped provider keys.
/// 3. The generic client for a registry-added provider (https only).
///
/// Throws [ProviderException] for an unknown key with no usable
/// registry entry — never an [ArgumentError], so the tracker can
/// record it as a per-account error instead of crashing the refresh.
GpsProviderClient clientForSavedVehicle(
  String providerKey,
  ProviderRegistry? registry,
) {
  final override = registry?.overrideFor(providerKey);
  if (override != null) return RemoteProviderClient(override);
  for (final provider in GpsProvider.values) {
    if (provider.key == providerKey) return clientFor(provider);
  }
  final entry = registry?.entryFor(providerKey);
  if (entry != null && entry.isHttps) return RemoteProviderClient(entry);
  throw ProviderException('Unknown provider "$providerKey".');
}

/// Shortest allowed gap between two polls for one account of
/// [providerKey]: the built-in minimum, or the registry entry's
/// minimum for a remote provider.
Duration minPollIntervalFor(String providerKey, ProviderRegistry? registry) {
  for (final provider in GpsProvider.values) {
    if (provider.key == providerKey) return provider.minPollInterval;
  }
  final entry = registry?.entryFor(providerKey);
  if (entry != null) {
    return Duration(seconds: entry.minPollIntervalSeconds);
  }
  return const Duration(seconds: 60);
}

/// Display name for a provider key, falling back to the key itself
/// for unknown keys (never throws).
String providerDisplayNameFor(String providerKey, ProviderRegistry? registry) {
  for (final provider in GpsProvider.values) {
    if (provider.key == providerKey) return provider.displayName;
  }
  return registry?.entryFor(providerKey)?.displayName ?? providerKey;
}
