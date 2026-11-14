import 'package:flutter/services.dart';

/// Applies a user-entered Google Maps API key at runtime, before the
/// first GoogleMap widget is built (v1.5.0).
///
/// google_maps_flutter normally reads the key from the manifest /
/// AppDelegate at build time, which does not work for a key the user
/// types in Settings. The native side (MainActivity on Android,
/// AppDelegate on iOS) applies the key through this channel:
/// - Android writes it into the ApplicationInfo meta-data Bundle
///   (`com.google.android.geo.API_KEY`), which the Maps SDK reads
///   when the first map is created.
/// - iOS calls `[GMSServices provideAPIKey:]`.
///
/// The native write is process-wide and sticky: applying a key once
/// is enough for the rest of the app session, and a changed key only
/// takes effect after an app restart (the SDK keeps the first key it
/// saw). Every failure — no platform, wrong key shape, native error —
/// returns false instead of throwing, so the UI can fall back to
/// OpenStreetMap.
class GoogleMapsKeyChannel {
  static const _channel = MethodChannel('unitrack/maps');

  /// The last key successfully applied in this process, or null.
  /// Static so every instance shares it — repeated calls with the
  /// same key are no-ops.
  static String? _appliedKey;

  /// Applies [key] if it has not been applied yet in this process.
  /// Returns true when the native side accepted it.
  Future<bool> ensureApplied(String key) async {
    if (_appliedKey == key) return true;
    try {
      final ok = await _channel.invokeMethod<bool>('applyApiKey', key);
      if (ok == true) {
        _appliedKey = key;
        return true;
      }
      return false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
