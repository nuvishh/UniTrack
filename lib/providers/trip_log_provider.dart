import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip_point.dart';
import '../models/vehicle.dart';
import 'tracker_provider.dart';

/// The local trip log: one [TripPoint] per vehicle per poll.
///
/// Poll snapshots are the only position history most providers give
/// (LiveTrace, HashTrace, Mercy/Pauldea return live snapshots only),
/// so the log is what powers day summaries for them. Providers with
/// server history (Aargee, Transight, SimplyTrack) merge their
/// history with this log in the vehicle detail screen.
///
/// Storage: one SharedPreferences JSON object, keyed by vehicle key
/// (`<providerKey>:<vehicleId>`), each a compact array of points.
/// Capped at 1000 points per vehicle and pruned to the last 7 days,
/// so the payload stays small.
class TripLogNotifier extends Notifier<Map<String, List<TripPoint>>> {
  static const _prefsKey = 'unitrack_trip_log_v1';
  static const maxPointsPerVehicle = 1000;
  static const retention = Duration(days: 7);

  @override
  Map<String, List<TripPoint>> build() {
    unawaited(_load());
    // Record every new fleet snapshot as it arrives.
    ref.listen(trackerProvider, (previous, next) {
      _record(next.vehicles);
    });
    return const {};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final log = <String, List<TripPoint>>{};
      for (final entry in decoded.entries) {
        final points = (entry.value as List<dynamic>)
            .map((p) => TripPoint.fromJson(p))
            .toList();
        if (points.isNotEmpty) log[entry.key] = points;
      }
      state = log;
    } catch (_) {
      // A corrupt log is dropped, never crash the app.
      state = const {};
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final encoded = jsonEncode(
      state.map(
        (key, points) =>
            MapEntry(key, points.map((p) => p.toJson()).toList()),
      ),
    );
    await prefs.setString(_prefsKey, encoded);
  }

  void _record(List<Vehicle> vehicles) {
    final now = DateTime.now();
    final cutoff = now.subtract(retention);
    var changed = false;
    final updated = Map<String, List<TripPoint>>.from(state);
    for (final vehicle in vehicles) {
      if (!vehicle.hasFix) continue;
      final key = vehicleKey(vehicle.providerKey, vehicle.id);
      final points = List<TripPoint>.from(updated[key] ?? const []);
      points.add(
        TripPoint(
          time: now,
          latitude: vehicle.latitude!,
          longitude: vehicle.longitude!,
          speedKmph: vehicle.speedKmph,
          ignition: vehicle.ignition,
        ),
      );
      // Prune old points, then cap the ring buffer.
      points.removeWhere((p) => p.time.isBefore(cutoff));
      if (points.length > maxPointsPerVehicle) {
        points.removeRange(0, points.length - maxPointsPerVehicle);
      }
      updated[key] = points;
      changed = true;
    }
    if (!changed) return;
    state = updated;
    unawaited(_save());
  }

  /// Points for one vehicle, optionally limited to one local day.
  List<TripPoint> pointsFor(String key, {DateTime? day}) {
    final points = state[key] ?? const [];
    if (day == null) return List.unmodifiable(points);
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return points
        .where((p) => !p.time.isBefore(start) && p.time.isBefore(end))
        .toList();
  }

  /// All points for one vehicle (unsorted copy).
  List<TripPoint> allPointsFor(String key) =>
      List.unmodifiable(state[key] ?? const []);
}

/// The local trip log for the whole app.
final tripLogProvider =
    NotifierProvider<TripLogNotifier, Map<String, List<TripPoint>>>(
      TripLogNotifier.new,
    );
