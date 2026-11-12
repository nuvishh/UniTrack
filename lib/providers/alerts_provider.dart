import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert.dart';
import '../models/vehicle.dart';
import '../services/fleet_events.dart';
import 'geofences_provider.dart';
import 'tracker_provider.dart';

/// Detected fleet alerts + the overspeed threshold setting.
///
/// The notifier listens to the fleet state: on every new poll snapshot
/// it compares each vehicle with its previous snapshot and records
/// ignition transitions, overspeed crossings and geofence crossings
/// (see [FleetEventDetector]). Alerts are stored in SharedPreferences,
/// newest first, capped at 100.
class AlertsState {
  const AlertsState({
    this.alerts = const [],
    this.overspeedThresholdKmh = 80,
  });

  final List<FleetAlert> alerts;

  /// Speed above which an overspeed alert fires (km/h).
  final double overspeedThresholdKmh;

  AlertsState copyWith({
    List<FleetAlert>? alerts,
    double? overspeedThresholdKmh,
  }) {
    return AlertsState(
      alerts: alerts ?? this.alerts,
      overspeedThresholdKmh:
          overspeedThresholdKmh ?? this.overspeedThresholdKmh,
    );
  }
}

class AlertsNotifier extends Notifier<AlertsState> {
  static const _alertsKey = 'unitrack_alerts_v1';
  static const _thresholdKey = 'unitrack_overspeed_threshold_kmh_v1';
  static const maxAlerts = 100;

  /// Last snapshot per vehicle key, for transition detection.
  final Map<String, Vehicle> _previousByKey = {};

  /// Geofence inside/outside state per geofence id.
  final Map<String, bool> _insideByGeofenceId = {};

  @override
  AlertsState build() {
    unawaited(_load());
    ref.listen(trackerProvider, (previous, next) {
      _detect(next.vehicles);
    });
    return const AlertsState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final raw = prefs.getString(_alertsKey);
    final threshold = prefs.getDouble(_thresholdKey) ?? 80;
    var alerts = const <FleetAlert>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        alerts = decoded
            .whereType<Map<String, dynamic>>()
            .map(FleetAlert.fromJson)
            .toList();
      } catch (_) {
        alerts = const [];
      }
    }
    state = AlertsState(
      alerts: alerts,
      overspeedThresholdKmh: threshold,
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    await prefs.setString(
      _alertsKey,
      jsonEncode(state.alerts.map((a) => a.toJson()).toList()),
    );
    await prefs.setDouble(
      _thresholdKey,
      state.overspeedThresholdKmh,
    );
  }

  void _detect(List<Vehicle> vehicles) {
    final geofences = ref.read(geofencesProvider);
    final fresh = <FleetAlert>[];
    for (final vehicle in vehicles) {
      final key = '${vehicle.providerKey}:${vehicle.id}';
      final previous = _previousByKey[key];
      final vehicleFences = geofences
          .where((f) => f.vehicleKey == key)
          .toList();
      fresh.addAll(
        FleetEventDetector.detect(
          previous: previous,
          next: vehicle,
          overspeedThresholdKmh: state.overspeedThresholdKmh,
          geofences: vehicleFences,
          insideByGeofenceId: _insideByGeofenceId,
        ),
      );
      _previousByKey[key] = vehicle;
    }
    if (fresh.isEmpty) return;
    final alerts = [...fresh, ...state.alerts];
    if (alerts.length > maxAlerts) {
      alerts.removeRange(maxAlerts, alerts.length);
    }
    state = state.copyWith(alerts: alerts);
    unawaited(_save());
  }

  /// Changes the overspeed threshold (persisted).
  Future<void> setOverspeedThreshold(double kmh) async {
    state = state.copyWith(overspeedThresholdKmh: kmh);
    await _save();
  }

  /// Deletes every stored alert.
  Future<void> clearAll() async {
    state = state.copyWith(alerts: const []);
    await _save();
  }

  /// Alerts of one type, newest first.
  List<FleetAlert> alertsOfType(AlertType? type) {
    if (type == null) return state.alerts;
    return state.alerts.where((a) => a.type == type).toList();
  }
}

/// Detected fleet alerts for the whole app.
final alertsProvider = NotifierProvider<AlertsNotifier, AlertsState>(
  AlertsNotifier.new,
);
