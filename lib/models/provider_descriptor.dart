import 'gps_provider.dart';
import 'provider_registry.dart';

/// One provider in the add-vehicle list, whether built-in (from the
/// [GpsProvider] enum) or remote (from the provider registry).
///
/// The wizard and the fleet screens work with descriptors, so a
/// registry-provided provider behaves like a built-in one in the UI —
/// except for the "Remote" badge that tells the user it came from the
/// downloaded registry, not from the shipped app.
class ProviderDescriptor {
  const ProviderDescriptor({
    required this.key,
    required this.displayName,
    required this.deviceIdLabel,
    required this.deviceIdHint,
    required this.secretLabel,
    required this.secretHint,
    required this.authKind,
    required this.supportsHistory,
    required this.isRemote,
    required this.verified,
    required this.rateLimitNote,
  });

  /// Lowercase key, e.g. 'aargee'.
  final String key;
  final String displayName;

  /// Add-vehicle form labels.
  final String deviceIdLabel;
  final String deviceIdHint;
  final String secretLabel;
  final String secretHint;

  /// 'apiKey' | 'userIdAndKey' | 'usernamePassword'.
  final String authKind;

  final bool supportsHistory;

  /// True when this provider came from the downloaded registry.
  final bool isRemote;

  /// True when the API contract was verified live.
  final bool verified;

  final String rateLimitNote;

  factory ProviderDescriptor.fromBuiltin(GpsProvider provider) {
    return ProviderDescriptor(
      key: provider.key,
      displayName: provider.displayName,
      deviceIdLabel: provider.deviceIdLabel,
      deviceIdHint: provider.deviceIdHint,
      secretLabel: provider.secretLabel,
      secretHint: provider.secretHint,
      authKind: provider.authType.name,
      supportsHistory: provider.supportsHistory,
      isRemote: false,
      verified: provider.verified,
      rateLimitNote: provider.rateLimitNote,
    );
  }

  factory ProviderDescriptor.fromEntry(RegistryEntry entry) {
    return ProviderDescriptor(
      key: entry.key,
      displayName: entry.displayName,
      deviceIdLabel: entry.deviceIdLabel,
      deviceIdHint: entry.deviceIdHint,
      secretLabel: entry.secretLabel,
      secretHint: entry.secretHint,
      authKind: entry.authKind,
      supportsHistory: entry.supportsHistory,
      isRemote: true,
      verified: entry.verified,
      rateLimitNote: entry.rateLimitNote,
    );
  }
}
