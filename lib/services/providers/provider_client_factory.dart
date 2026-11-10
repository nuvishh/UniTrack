import '../../models/gps_provider.dart';
import 'aargee_client.dart';
import 'gps_provider_client.dart';
import 'hashtrace_client.dart';
import 'livetrace_client.dart';
import 'mercydatrack_client.dart';
import 'pauldeatrack_client.dart';
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
