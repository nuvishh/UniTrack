import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gps_provider.dart';
import '../models/provider_descriptor.dart';
import '../models/provider_registry.dart';
import '../services/provider_registry_service.dart';

/// State of the downloaded provider registry.
class RegistryState {
  const RegistryState({
    this.registry,
    this.source = RegistrySource.none,
    this.fetchedAt,
    this.isRefreshing = false,
  });

  /// The loaded registry, or null when none is available (built-ins
  /// only). Never null just because the device is offline — the cache
  /// is used then.
  final ProviderRegistry? registry;

  final RegistrySource source;

  /// When the registry was last fetched or read from cache.
  final DateTime? fetchedAt;

  /// True while a manual refresh is in flight.
  final bool isRefreshing;

  RegistryState copyWith({
    ProviderRegistry? registry,
    RegistrySource? source,
    DateTime? fetchedAt,
    bool? isRefreshing,
  }) {
    return RegistryState(
      registry: registry ?? this.registry,
      source: source ?? this.source,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

/// Loads the provider registry in the background (cache first, then a
/// silent fetch) and refreshes it on demand from Settings. A failed
/// fetch never changes the state to an error — the app keeps working
/// on built-ins (or the last good cache).
class RegistryNotifier extends Notifier<RegistryState> {
  final _service = ProviderRegistryService();

  @override
  RegistryState build() {
    unawaited(_load());
    return const RegistryState();
  }

  Future<void> _load() async {
    RegistryLoadResult result;
    try {
      result = await _service.load();
    } catch (_) {
      // Loading must never break the app (e.g. storage unavailable):
      // built-ins only.
      return;
    }
    if (!ref.mounted) return;
    state = RegistryState(
      registry: result.registry,
      source: result.source,
      fetchedAt: result.fetchedAt,
    );
  }

  /// Forces a fresh fetch (Settings → "Refresh providers").
  /// Returns true when a registry is available afterwards.
  Future<bool> refresh() async {
    state = state.copyWith(isRefreshing: true);
    final result = await _service.load(forceRefresh: true);
    if (!ref.mounted) return result.registry != null;
    state = RegistryState(
      registry: result.registry,
      source: result.source,
      fetchedAt: result.fetchedAt,
    );
    return result.registry != null;
  }
}

/// The downloaded provider registry for the whole app.
final registryProvider =
    NotifierProvider<RegistryNotifier, RegistryState>(RegistryNotifier.new);

/// All providers the user can pick in the add-vehicle wizard: the 7
/// built-ins first, then registry-added providers (https only) with a
/// "Remote" badge in the UI.
final providerDescriptorsProvider = Provider<List<ProviderDescriptor>>((
  ref,
) {
  final registry = ref.watch(registryProvider).registry;
  final descriptors = GpsProvider.values
      .map(ProviderDescriptor.fromBuiltin)
      .toList();
  if (registry != null) {
    for (final entry in registry.newProviders) {
      descriptors.add(ProviderDescriptor.fromEntry(entry));
    }
  }
  return descriptors;
});

/// One registry entry by key, or null when the key is built-in or
/// not in the registry.
final registryEntryProvider = Provider.family<RegistryEntry?, String>((
  ref,
  key,
) {
  return ref.watch(registryProvider).registry?.entryFor(key);
});
