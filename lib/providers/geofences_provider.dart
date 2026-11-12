import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/geofence.dart';

/// Circular geofences, one list for the whole fleet, stored in
/// SharedPreferences. Created from a vehicle's detail screen; the
/// alert detector watches them for enter/exit crossings.
class GeofenceNotifier extends Notifier<List<Geofence>> {
  static const _prefsKey = 'unitrack_geofences_v1';

  @override
  List<Geofence> build() {
    unawaited(_load());
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      state = decoded
          .whereType<Map<String, dynamic>>()
          .map(Geofence.fromJson)
          .toList();
    } catch (_) {
      state = const [];
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    await prefs.setString(
      _prefsKey,
      jsonEncode(state.map((g) => g.toJson()).toList()),
    );
  }

  Future<void> add(Geofence geofence) async {
    state = [...state, geofence];
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((g) => g.id != id).toList();
    await _save();
  }

  /// Geofences watching one vehicle.
  List<Geofence> forVehicle(String vehicleKey) =>
      state.where((g) => g.vehicleKey == vehicleKey).toList();
}

/// Geofences for the whole app.
final geofencesProvider =
    NotifierProvider<GeofenceNotifier, List<Geofence>>(GeofenceNotifier.new);
