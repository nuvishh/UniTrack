import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/provider_registry.dart';

/// Where a registry came from.
enum RegistrySource {
  /// No registry available — built-in providers only.
  none,

  /// Loaded from the on-device cache.
  cached,

  /// Fetched fresh from the server just now.
  remote,
}

/// Result of a registry load.
class RegistryLoadResult {
  const RegistryLoadResult({
    required this.registry,
    required this.source,
    this.fetchedAt,
  });

  final ProviderRegistry? registry;
  final RegistrySource source;
  final DateTime? fetchedAt;
}

/// Fetches the provider registry and caches it on-device.
///
/// - The registry URL is FIXED in code (never itself configurable from
///   the registry) and HTTPS-only.
/// - Cached for 24h; a stale cache is still used when the fetch fails.
/// - Every failure is silent (log only via debugPrint in debug builds
///   — the app must never break when offline): the caller gets the
///   last good cache, or null (built-ins only).
/// - No credentials are ever involved: the registry carries
///   placeholders only, and the generic client only sends a user's
///   saved credentials to the baseUrl of the provider they configured.
class ProviderRegistryService {
  static const registryUrl =
      'https://raw.githubusercontent.com/nuvishh/UniTrack/main/providers/registry.json';

  static const cacheTtl = Duration(hours: 24);

  static const _cacheKey = 'unitrack_provider_registry_v1';
  static const _fetchedAtKey = 'unitrack_provider_registry_fetched_at_v1';

  /// Loads the registry: fresh cache first, else a fetch, else a stale
  /// cache, else null. Pass [forceRefresh] for the Settings "Refresh
  /// providers" action.
  Future<RegistryLoadResult> load({
    http.Client? httpClient,
    bool forceRefresh = false,
  }) async {
    try {
      return await _loadInner(
        httpClient: httpClient,
        forceRefresh: forceRefresh,
      );
    } catch (_) {
      // SharedPreferences (or anything else) unavailable — the app
      // keeps working on the built-in providers.
      return const RegistryLoadResult(
        registry: null,
        source: RegistrySource.none,
      );
    }
  }

  Future<RegistryLoadResult> _loadInner({
    http.Client? httpClient,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = _readCache(prefs);
    if (!forceRefresh &&
        cached != null &&
        !_isStale(cached.fetchedAt)) {
      return RegistryLoadResult(
        registry: cached.registry,
        source: RegistrySource.cached,
        fetchedAt: cached.fetchedAt,
      );
    }
    final fetched = await _fetch(httpClient);
    if (fetched != null) {
      await _writeCache(prefs, fetched);
      return RegistryLoadResult(
        registry: fetched.registry,
        source: RegistrySource.remote,
        fetchedAt: fetched.fetchedAt,
      );
    }
    if (cached != null) {
      return RegistryLoadResult(
        registry: cached.registry,
        source: RegistrySource.cached,
        fetchedAt: cached.fetchedAt,
      );
    }
    return const RegistryLoadResult(
      registry: null,
      source: RegistrySource.none,
    );
  }

  bool _isStale(DateTime? fetchedAt) {
    if (fetchedAt == null) return true;
    return DateTime.now().difference(fetchedAt) > cacheTtl;
  }

  ({ProviderRegistry registry, DateTime fetchedAt})? _readCache(
    SharedPreferences prefs,
  ) {
    final raw = prefs.getString(_cacheKey);
    final fetchedAtMs = prefs.getInt(_fetchedAtKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return (
        registry: parseProviderRegistry(raw),
        fetchedAt: fetchedAtMs == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.fromMillisecondsSinceEpoch(fetchedAtMs),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(
    SharedPreferences prefs,
    ({ProviderRegistry registry, DateTime fetchedAt}) fetched,
  ) async {
    // The raw JSON is re-encoded from the parsed registry so the cache
    // is always well-formed; entry order and fields are preserved.
    final encoded = jsonEncode({
      'version': fetched.registry.version,
      'providers': fetched.registry.entries.map(_entryToJson).toList(),
    });
    await prefs.setString(_cacheKey, encoded);
    await prefs.setInt(
      _fetchedAtKey,
      fetched.fetchedAt.millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> _entryToJson(RegistryEntry entry) {
    return {
      'key': entry.key,
      'displayName': entry.displayName,
      'baseUrl': entry.baseUrl,
      'auth': {
        'style': entry.auth.style,
        'param': entry.auth.param,
        'headerName': entry.auth.headerName,
        'bodyField': entry.auth.bodyField,
        'secretFormat': entry.auth.secretFormat,
      },
      'deviceIdLabel': entry.deviceIdLabel,
      'deviceIdHint': entry.deviceIdHint,
      'secretLabel': entry.secretLabel,
      'secretHint': entry.secretHint,
      'authKind': entry.authKind,
      'supportsHistory': entry.supportsHistory,
      'verified': entry.verified,
      'genericCompatible': entry.genericCompatible,
      'overrideBuiltin': entry.overrideBuiltin,
      'timeoutSeconds': entry.timeoutSeconds,
      'minPollIntervalSeconds': entry.minPollIntervalSeconds,
      'rateLimitNote': entry.rateLimitNote,
      'fleet': _endpointToJson(entry.fleetEndpoint),
      if (entry.vehicleEndpoint != null)
        'vehicle': _endpointToJson(entry.vehicleEndpoint!),
      if (entry.historyEndpoint != null)
        'history': _endpointToJson(entry.historyEndpoint!),
      if (entry.historyDeviceParam != null)
        'historyDeviceParam': {
          'vehicleIdParam': entry.historyDeviceParam!.vehicleIdParam,
          'imeiParam': entry.historyDeviceParam!.imeiParam,
        },
      'fields': {
        'id': entry.fields.id,
        'displayName': entry.fields.displayName,
        if (entry.fields.imei != null) 'imei': entry.fields.imei,
        if (entry.fields.latitude != null)
          'latitude': entry.fields.latitude,
        if (entry.fields.longitude != null)
          'longitude': entry.fields.longitude,
        if (entry.fields.speed != null) 'speed': entry.fields.speed,
        if (entry.fields.ignition != null)
          'ignition': entry.fields.ignition,
        if (entry.fields.lastUpdated != null)
          'lastUpdated': entry.fields.lastUpdated,
        'trueValues': entry.fields.trueValues,
        'falseValues': entry.fields.falseValues,
      },
      if (entry.listPath != null) 'listPath': entry.listPath,
      if (entry.locationField != null)
        'locationField': entry.locationField,
      if (entry.successCheck != null)
        'successCheck': {
          'field': entry.successCheck!.field,
          'equals': entry.successCheck!.equals,
        },
      'deviceMatching': entry.deviceMatching,
    };
  }

  Map<String, dynamic> _endpointToJson(RegistryEndpoint endpoint) {
    return {
      'method': endpoint.method,
      'path': endpoint.path,
      if (endpoint.query.isNotEmpty) 'query': endpoint.query,
      if (endpoint.body != null) 'body': endpoint.body,
    };
  }

  Future<({ProviderRegistry registry, DateTime fetchedAt})?> _fetch(
    http.Client? httpClient,
  ) async {
    final client = httpClient ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse(registryUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final registry = parseProviderRegistry(response.body);
      return (registry: registry, fetchedAt: DateTime.now());
    } catch (_) {
      // Silent by design: offline / bad JSON / bad cert all fall back
      // to the cache (or to built-ins when there is no cache).
      return null;
    } finally {
      if (httpClient == null) client.close();
    }
  }
}
