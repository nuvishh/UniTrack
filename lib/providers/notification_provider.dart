import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/alert_rules.dart';
import '../services/notification_service.dart';

/// The app's notification service (a plain [Provider] so tests can
/// override it with a recording fake).
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

/// Owns the vehicle-alert toggles and persists them.
///
/// Same mechanism as [ThemeNotifier]: SharedPreferences, one bool
/// key per toggle. Every toggle defaults to on.
class AlertSettingsNotifier extends Notifier<AlertSettings> {
  /// SharedPreferences keys for the alert toggles.
  static const masterKey = 'unitrack_alerts_master_v1';
  static const ignitionKey = 'unitrack_alerts_ignition_v1';
  static const overspeedKey = 'unitrack_alerts_overspeed_v1';
  static const offlineKey = 'unitrack_alerts_offline_v1';

  @override
  AlertSettings build() {
    // Load the saved toggles in the background; everything is on
    // until they arrive.
    unawaited(_load());
    return const AlertSettings();
  }

  Future<void> setMaster(bool value) async {
    state = state.copyWith(master: value);
    await _save();
  }

  Future<void> setIgnition(bool value) async {
    state = state.copyWith(ignition: value);
    await _save();
  }

  Future<void> setOverspeed(bool value) async {
    state = state.copyWith(overspeed: value);
    await _save();
  }

  Future<void> setOffline(bool value) async {
    state = state.copyWith(offline: value);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(masterKey, state.master);
    await prefs.setBool(ignitionKey, state.ignition);
    await prefs.setBool(overspeedKey, state.overspeed);
    await prefs.setBool(offlineKey, state.offline);
  }

  Future<void> _load() async {
    // A failed load (e.g. no platform in a unit test) keeps the
    // defaults — never let a storage error break the app start.
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      state = AlertSettings(
        master: prefs.getBool(masterKey) ?? true,
        ignition: prefs.getBool(ignitionKey) ?? true,
        overspeed: prefs.getBool(overspeedKey) ?? true,
        offline: prefs.getBool(offlineKey) ?? true,
      );
    } catch (_) {
      // Keep the defaults (all on).
    }
  }
}

/// The vehicle-alert toggles for the whole app.
final alertSettingsProvider =
    NotifierProvider<AlertSettingsNotifier, AlertSettings>(
      AlertSettingsNotifier.new,
    );
