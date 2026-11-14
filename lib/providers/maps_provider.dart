import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/google_maps_key_channel.dart';
import '../services/map_mode.dart';
import 'storage_provider.dart';

/// The user's own Google Maps API key (v1.5.0), saved in secure
/// storage under `google_maps_api_key` like the provider secrets.
/// Null until loaded, and null when no key is saved.
///
/// Saving also applies the key to the native Maps SDK immediately
/// (via [GoogleMapsKeyChannel]); a changed key needs an app restart
/// to take effect in a map that already initialised.
class GoogleMapsKeyNotifier extends Notifier<String?> {
  final GoogleMapsKeyChannel _channel = GoogleMapsKeyChannel();

  @override
  String? build() {
    unawaited(_load());
    return null;
  }

  Future<void> _load() async {
    try {
      final key = await ref
          .read(secureStorageServiceProvider)
          .readGoogleMapsApiKey();
      if (!ref.mounted) return;
      state = key;
      // Apply the saved key to the native SDK at startup, so the
      // Map tab can build a GoogleMap immediately.
      if (key != null && key.isNotEmpty) {
        unawaited(_channel.ensureApplied(key));
      }
    } catch (_) {
      // Keep null (OpenStreetMap) — never break app start on storage.
    }
  }

  /// Saves [key] (empty clears it) and applies it to the native SDK.
  /// Returns true when the key was applied to the SDK (or when there
  /// is no key to apply); false only when the SDK rejected it — the
  /// key is still saved, and the map tab falls back to OpenStreetMap.
  Future<bool> setKey(String key) async {
    final trimmed = key.trim();
    final storage = ref.read(secureStorageServiceProvider);
    if (trimmed.isEmpty) {
      await storage.deleteGoogleMapsApiKey();
      state = null;
      return true;
    }
    await storage.saveGoogleMapsApiKey(trimmed);
    state = trimmed;
    return _channel.ensureApplied(trimmed);
  }

  Future<void> clearKey() async {
    await ref.read(secureStorageServiceProvider).deleteGoogleMapsApiKey();
    state = null;
  }
}

/// The saved Google Maps API key, or null when none is saved.
final googleMapsKeyProvider =
    NotifierProvider<GoogleMapsKeyNotifier, String?>(GoogleMapsKeyNotifier.new);

/// The map type the user last picked on the Map tab, persisted in
/// SharedPreferences under `unitrack_map_type_v1`.
///
/// Null means "no explicit choice" — the default then follows the
/// key: Google Maps when a key is saved, OpenStreetMap otherwise
/// (see [selectMapType]).
class MapTypeNotifier extends Notifier<MapType?> {
  static const prefsKey = 'unitrack_map_type_v1';

  @override
  MapType? build() {
    unawaited(_load());
    return null;
  }

  Future<void> setMapType(MapType? value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(prefsKey);
    } else {
      await prefs.setString(prefsKey, value.name);
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      final raw = prefs.getString(prefsKey);
      if (raw != null) state = MapType.fromName(raw);
    } catch (_) {
      // Keep null (default) — never break app start on storage.
    }
  }
}

/// The user's explicit map-type choice, or null for the default.
final mapTypeProvider = NotifierProvider<MapTypeNotifier, MapType?>(
  MapTypeNotifier.new,
);
