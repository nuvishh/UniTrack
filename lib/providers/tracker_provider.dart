import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vehicle.dart';
import '../services/alert_rules.dart';
import '../services/tracker_service.dart';
import 'locale_provider.dart';
import 'notification_provider.dart';
import 'registry_provider.dart';
import 'storage_provider.dart';

/// Immutable snapshot of the fleet's live state.
///
/// [TrackerService] still does all the fetching and polling — this
/// state is a read-only mirror of it, rebuilt whenever the service
/// changes, so screens only ever watch Riverpod state.
class TrackerState {
  const TrackerState({
    this.vehicles = const [],
    this.isRefreshing = false,
    this.lastError,
    this.refreshInterval = const Duration(seconds: 60),
  });

  /// All vehicles currently known, de-duplicated by provider + id.
  final List<Vehicle> vehicles;

  /// True while a refresh is in flight.
  final bool isRefreshing;

  /// Human-readable per-account errors from the last refresh, or null.
  final String? lastError;

  /// The user's global poll interval. Providers enforce their own
  /// minimum on top of this (see [GpsProvider.minPollInterval]).
  final Duration refreshInterval;

  TrackerState copyWith({
    List<Vehicle>? vehicles,
    bool? isRefreshing,
    String? lastError,
    Duration? refreshInterval,
  }) {
    return TrackerState(
      vehicles: vehicles ?? this.vehicles,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastError: lastError ?? this.lastError,
      refreshInterval: refreshInterval ?? this.refreshInterval,
    );
  }
}

/// Owns the fleet: wraps [TrackerService] (which keeps all the fetch
/// and polling logic) and mirrors its state into Riverpod.
///
/// The service is created once, in [build]; its ValueNotifier
/// listeners push every change into this state, and [ref.onDispose]
/// tears the service down with the provider. Screens never touch the
/// service directly — they watch [trackerProvider] and call the
/// notifier's methods.
class TrackerNotifier extends Notifier<TrackerState> {
  late final TrackerService _service;
  bool _disposed = false;

  @override
  TrackerState build() {
    _service = TrackerService(storage: ref.read(secureStorageServiceProvider));
    _service.vehicles.addListener(_syncFromService);
    _service.isRefreshing.addListener(_syncFromService);
    _service.lastError.addListener(_syncFromService);
    // The downloaded registry (when one arrives) lets the service
    // poll registry-added providers too; built-ins are unaffected.
    ref.listen(registryProvider, (_, next) {
      _service.registry = next.registry;
    });
    ref.onDispose(() {
      _disposed = true;
      _service.vehicles.removeListener(_syncFromService);
      _service.isRefreshing.removeListener(_syncFromService);
      _service.lastError.removeListener(_syncFromService);
      _service.dispose();
    });
    // First load + polling start in the background; the service's
    // listeners mirror every change back into this state.
    unawaited(_initialize());
    return const TrackerState();
  }

  void _syncFromService() {
    if (_disposed) return;
    final previous = state.vehicles;
    final next = _service.vehicles.value;
    // The service is the source of truth; mirror all of it at once.
    state = TrackerState(
      vehicles: _service.vehicles.value,
      isRefreshing: _service.isRefreshing.value,
      lastError: _service.lastError.value,
      refreshInterval: _service.refreshInterval,
    );
    // Vehicle alerts (v1.4.0): compare the new snapshot with the
    // one it replaces and notify on transitions (ignition on/off,
    // offline, overspeed). Fire-and-forget — a notification failure
    // never blocks the fleet update.
    final alerts = alertTransitions(
      previous: previous,
      current: next,
      settings: ref.read(alertSettingsProvider),
    );
    if (alerts.isNotEmpty) {
      final locale =
          ref.read(localeProvider).locale ??
          ui.PlatformDispatcher.instance.locale;
      unawaited(
        ref
            .read(notificationServiceProvider)
            .showAlerts(alerts, locale: locale),
      );
    }
  }

  Future<void> _initialize() async {
    await _service.init();
    if (_disposed) return;
    _syncFromService();
    await _service.refreshAll();
    if (_disposed) return;
    _service.startPolling();
  }

  /// Refreshes every saved account that is due for a poll.
  Future<void> refreshAll() async {
    await _service.refreshAll();
    _syncFromService();
  }

  /// Changes the global poll interval (persisted) and restarts polling.
  Future<void> setRefreshInterval(Duration interval) async {
    await _service.setRefreshInterval(interval);
    _syncFromService();
  }

  /// Fetches history for [vehicle] between [from] and [to].
  /// Throws [UnsupportedError] for live-snapshot-only providers.
  Future<List<Vehicle>> fetchHistoryFor(
    Vehicle vehicle, {
    required DateTime from,
    required DateTime to,
  }) => _service.fetchHistoryFor(vehicle, from: from, to: to);
}

/// The fleet's live state for the whole app.
final trackerProvider = NotifierProvider<TrackerNotifier, TrackerState>(
  TrackerNotifier.new,
);
