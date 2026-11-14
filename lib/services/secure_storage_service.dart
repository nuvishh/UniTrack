import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_vehicle.dart';

/// Storage for UniTrack.
///
/// Split by design:
/// - Secrets (API keys / passwords) live ONLY in flutter_secure_storage
///   (Keychain on iOS, EncryptedSharedPreferences on Android) under
///   `unitrack_secret_<vehicleId>`. They are never logged, never put in
///   shared_preferences, and never sent anywhere except the provider's
///   own API.
/// - The vehicle list (provider, device id, reg no, display name — NO
///   secrets) lives in shared_preferences as JSON.
/// - The refresh interval lives in shared_preferences.
class SecureStorageService {
  static const _vehiclesKey = 'unitrack_saved_vehicles_v1';
  static const _intervalKey = 'unitrack_refresh_interval_seconds';
  static const _defaultIntervalSeconds = 60;

  /// The user's own Google Maps API key (v1.5.0) — same treatment
  /// as provider secrets: secure storage only, never logged.
  static const _googleMapsApiKey = 'google_maps_api_key';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  String _secretKey(String vehicleId) => 'unitrack_secret_$vehicleId';

  Future<List<SavedVehicle>> loadVehicles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_vehiclesKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(SavedVehicle.fromJson)
        .toList();
  }

  /// Saves a vehicle (non-secret fields) and its secret together.
  Future<void> saveVehicle(SavedVehicle vehicle, String secret) async {
    final vehicles = await loadVehicles();
    vehicles.removeWhere((v) => v.id == vehicle.id);
    vehicles.add(vehicle);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _vehiclesKey,
      jsonEncode(vehicles.map((v) => v.toJson()).toList()),
    );
    await _secure.write(key: _secretKey(vehicle.id), value: secret);
  }

  /// Removes a vehicle and deletes its secret.
  Future<void> deleteVehicle(String vehicleId) async {
    final vehicles = await loadVehicles();
    vehicles.removeWhere((v) => v.id == vehicleId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _vehiclesKey,
      jsonEncode(vehicles.map((v) => v.toJson()).toList()),
    );
    await _secure.delete(key: _secretKey(vehicleId));
  }

  /// Reads the secret for a vehicle, or null when none was saved.
  Future<String?> readSecret(String vehicleId) =>
      _secure.read(key: _secretKey(vehicleId));

  /// Reads the user's Google Maps API key, or null when none is saved.
  Future<String?> readGoogleMapsApiKey() =>
      _secure.read(key: _googleMapsApiKey);

  /// Saves the user's Google Maps API key.
  Future<void> saveGoogleMapsApiKey(String key) =>
      _secure.write(key: _googleMapsApiKey, value: key);

  /// Deletes the user's Google Maps API key.
  Future<void> deleteGoogleMapsApiKey() =>
      _secure.delete(key: _googleMapsApiKey);

  Future<Duration> getRefreshInterval() async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt(_intervalKey) ?? _defaultIntervalSeconds;
    return Duration(seconds: seconds);
  }

  Future<void> setRefreshInterval(Duration interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_intervalKey, interval.inSeconds);
  }
}
