import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/gps_provider.dart';
import '../models/provider_credentials.dart';
import '../models/saved_vehicle.dart';
import '../models/vehicle.dart';
import '../utils/parsing.dart';
import 'providers/gps_provider_client.dart';
import 'providers/provider_client_factory.dart';
import 'secure_storage_service.dart';

/// Aggregates live vehicles across all saved provider accounts.
///
/// Polls on a timer (default 60s). Each provider account is never polled
/// faster than its own [GpsProvider.minPollInterval], however short the
/// user sets the global interval — this is what keeps SimplyTrack inside
/// its 100 requests/hour limit and Aargee inside its daily limits.
///
/// State is exposed through [ValueNotifier]s so screens rebuild on
/// every refresh. A failure for one account never blocks the others;
/// per-account errors are collected in [lastError].
class TrackerService {
  TrackerService({required this.storage, this.httpClient});

  final SecureStorageService storage;

  /// Test seam: an injected HTTP client is passed through to providers.
  final http.Client? httpClient;

  /// All vehicles currently known, de-duplicated by provider + id.
  final ValueNotifier<List<Vehicle>> vehicles = ValueNotifier([]);

  final ValueNotifier<bool> isRefreshing = ValueNotifier(false);

  /// Human-readable per-account errors from the last refresh, or null.
  final ValueNotifier<String?> lastError = ValueNotifier(null);

  Duration refreshInterval = const Duration(seconds: 60);

  final Map<String, DateTime> _lastFetchByAccount = {};
  Timer? _timer;

  Future<void> init() async {
    refreshInterval = await storage.getRefreshInterval();
  }

  void startPolling() {
    stopPolling();
    _timer = Timer.periodic(refreshInterval, (_) => refreshAll());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> setRefreshInterval(Duration interval) async {
    refreshInterval = interval;
    await storage.setRefreshInterval(interval);
    startPolling();
  }

  /// Refreshes every saved account that is due for a poll.
  Future<void> refreshAll() async {
    if (isRefreshing.value) return;
    isRefreshing.value = true;
    try {
      final saved = await storage.loadVehicles();
      final merged = <String, Vehicle>{
        for (final v in vehicles.value) '${v.providerKey}:${v.id}': v,
      };
      final errors = <String>[];
      for (final account in saved) {
        await _refreshAccount(account, merged, errors);
      }
      final sorted = merged.values.toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      vehicles.value = sorted;
      lastError.value = errors.isEmpty ? null : errors.join('\n');
    } finally {
      isRefreshing.value = false;
    }
  }

  Future<void> _refreshAccount(
    SavedVehicle account,
    Map<String, Vehicle> merged,
    List<String> errors,
  ) async {
    final provider = GpsProvider.fromKey(account.providerKey);
    final accountKey = '${account.providerKey}:${account.deviceId}';
    final lastFetch = _lastFetchByAccount[accountKey];
    if (lastFetch != null &&
        DateTime.now().difference(lastFetch) < provider.minPollInterval) {
      return;
    }
    try {
      final secret = await storage.readSecret(account.id);
      if (secret == null || secret.isEmpty) {
        errors.add(
          '${account.displayName ?? account.deviceId}: no credentials saved.',
        );
        return;
      }
      final client = clientFor(provider);
      final credentials = ProviderCredentials(
        deviceId: account.deviceId,
        secret: secret,
        regNo: account.regNo,
        displayName: account.displayName,
      );
      final fetched = await client.fetchLiveVehicles(
        credentials,
        httpClient: httpClient,
      );
      _lastFetchByAccount[accountKey] = DateTime.now();
      for (final vehicle in fetched) {
        merged['${vehicle.providerKey}:${vehicle.id}'] = vehicle;
      }
    } on ProviderException catch (e) {
      errors.add('${provider.displayName}: ${e.message}');
    } on UnsupportedError catch (e) {
      errors.add('${provider.displayName}: ${e.message}');
    }
  }

  /// Fetches history for [vehicle] between [from] and [to], using the
  /// saved account that matches it (by provider + device id / IMEI /
  /// reg no, falling back to the first account of that provider).
  /// Throws [UnsupportedError] for live-snapshot-only providers.
  Future<List<Vehicle>> fetchHistoryFor(
    Vehicle vehicle, {
    required DateTime from,
    required DateTime to,
  }) async {
    final saved = await storage.loadVehicles();
    final sameProvider = saved
        .where((s) => s.providerKey == vehicle.providerKey)
        .toList();
    if (sameProvider.isEmpty) {
      throw ProviderException(
        'No saved ${vehicle.providerKey} account to fetch history from.',
      );
    }
    SavedVehicle? account;
    for (final candidate in sameProvider) {
      final matchesId = candidate.deviceId == vehicle.id;
      final matchesImei =
          vehicle.imei != null && candidate.deviceId == vehicle.imei;
      final matchesReg =
          candidate.regNo != null &&
          normalizeRegNo(candidate.regNo!) ==
              normalizeRegNo(vehicle.displayName);
      if (matchesId || matchesImei || matchesReg) {
        account = candidate;
        break;
      }
    }
    account ??= sameProvider.first;
    final secret = await storage.readSecret(account.id);
    if (secret == null || secret.isEmpty) {
      throw ProviderException('No credentials saved for this account.');
    }
    final client = clientFor(GpsProvider.fromKey(account.providerKey));
    return client.fetchHistory(
      ProviderCredentials(
        deviceId: account.deviceId,
        secret: secret,
        regNo: account.regNo,
        displayName: account.displayName,
      ),
      from: from,
      to: to,
      httpClient: httpClient,
    );
  }

  void dispose() {
    stopPolling();
    vehicles.dispose();
    isRefreshing.dispose();
    lastError.dispose();
  }
}
