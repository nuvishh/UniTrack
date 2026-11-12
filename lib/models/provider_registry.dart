import 'dart:convert';

import 'gps_provider.dart';

/// A provider registry: providers described as data, so a new GPS
/// provider can be added (or an endpoint moved) without an app update.
///
/// The registry is fetched over HTTPS from a fixed URL (see
/// [ProviderRegistryService]) and cached. See providers/README.md for
/// the fallback rule: the built-in clients stay the source of truth,
/// a registry entry only ADDS a new provider, and it only overrides a
/// built-in when marked `overrideBuiltin` + `genericCompatible` AND its
/// base URL is https.
///
/// No real keys ever appear here — auth values are placeholders such
/// as `{authKey}`, filled in at request time from the user's own saved
/// credentials. Credentials are only ever sent to the baseUrl of the
/// provider the user configured.
class ProviderRegistry {
  const ProviderRegistry({
    required this.version,
    required this.entries,
    this.warnings = const [],
  });

  /// Registry format version. Bumped when the schema changes.
  final int version;

  /// Provider entries in file order.
  final List<RegistryEntry> entries;

  /// Non-fatal problems found while parsing (skipped entries, ...).
  final List<String> warnings;

  RegistryEntry? entryFor(String key) {
    for (final entry in entries) {
      if (entry.key == key) return entry;
    }
    return null;
  }

  /// The entry that may override a built-in provider: only when it is
  /// explicitly marked so, the generic client can fully serve it, and
  /// its base URL is https. Anything else falls back to the built-in.
  RegistryEntry? overrideFor(String key) {
    final entry = entryFor(key);
    if (entry == null) return null;
    if (!entry.overrideBuiltin) return null;
    if (!entry.genericCompatible) return null;
    if (!entry.isHttps) return null;
    return entry;
  }

  /// Entries for providers the app does not ship built-in, usable as
  /// new providers. Only https entries are ever usable — an http
  /// entry would send the user's credentials in cleartext.
  ///
  /// The built-in key set is derived from [GpsProvider.values], so a
  /// provider added to the app can never leak into this list as a
  /// "Remote" duplicate (as mercydatrack4g did in v1.2.0, when the
  /// hardcoded set below still listed only 7 keys).
  List<RegistryEntry> get newProviders {
    final builtinKeys = GpsProvider.values.map((p) => p.key).toSet();
    return entries
        .where((e) => !builtinKeys.contains(e.key) && e.isHttps)
        .toList();
  }
}

/// One provider, described as data.
class RegistryEntry {
  const RegistryEntry({
    required this.key,
    required this.displayName,
    required this.baseUrl,
    required this.auth,
    required this.deviceIdLabel,
    required this.deviceIdHint,
    required this.secretLabel,
    required this.secretHint,
    required this.authKind,
    required this.supportsHistory,
    required this.verified,
    required this.genericCompatible,
    required this.overrideBuiltin,
    required this.timeoutSeconds,
    required this.minPollIntervalSeconds,
    required this.rateLimitNote,
    required this.fleetEndpoint,
    this.vehicleEndpoint,
    this.historyEndpoint,
    this.historyDeviceParam,
    required this.fields,
    this.listPath,
    this.locationField,
    this.successCheck,
    this.deviceMatching = 'strict',
  });

  /// Lowercase key, e.g. 'hashtrace' (or a new provider's key).
  final String key;
  final String displayName;

  /// Base URL the user's credentials are sent to. Must be https for
  /// any entry the generic client serves.
  final String baseUrl;

  final RegistryAuth auth;

  /// Add-vehicle form labels.
  final String deviceIdLabel;
  final String deviceIdHint;
  final String secretLabel;
  final String secretHint;

  /// 'apiKey' | 'userIdAndKey' | 'usernamePassword'.
  final String authKind;

  final bool supportsHistory;

  /// True when the API contract was verified live.
  final bool verified;

  /// True when the generic client can fully serve this provider
  /// (all endpoints + field mappings expressible in the registry).
  final bool genericCompatible;

  /// True when this entry is allowed to replace the built-in client
  /// for the same key (only honoured together with
  /// [genericCompatible] and an https base URL).
  final bool overrideBuiltin;

  final int timeoutSeconds;
  final int minPollIntervalSeconds;
  final String rateLimitNote;

  /// Fleet (list) endpoint — always present.
  final RegistryEndpoint fleetEndpoint;

  /// Single-vehicle endpoint, when the provider has one.
  final RegistryEndpoint? vehicleEndpoint;

  /// History endpoint, when the provider supports history.
  final RegistryEndpoint? historyEndpoint;

  /// When history needs the device id under a different parameter
  /// name depending on its shape: numeric ids go to
  /// [vehicleIdParam], IMEIs to [imeiParam].
  final RegistryHistoryDeviceParam? historyDeviceParam;

  /// How to read a vehicle out of one response item.
  final RegistryFieldMapping fields;

  /// Dot path to the vehicle array inside the response, e.g. "data"
  /// or "response.LiveData". Null means the response root is the
  /// array (or a single vehicle object, which is wrapped in a list).
  final String? listPath;

  /// When coordinates arrive as one "lat lon" string, the field
  /// holding it (e.g. "location" for Aargee/Transight).
  final String? locationField;

  /// Optional success check, e.g. {"field": "status", "equals": 1}
  /// for Aargee-style APIs.
  final RegistrySuccessCheck? successCheck;

  /// 'strict' (default): the device id must match a returned vehicle,
  /// like the built-in clients. 'fleet': return the whole fleet
  /// (providers whose fleet call cannot address one vehicle).
  final String deviceMatching;

  bool get isHttps {
    final uri = Uri.tryParse(baseUrl);
    return uri != null && uri.scheme == 'https';
  }

  factory RegistryEntry.fromJson(Map<String, dynamic> json) {
    return RegistryEntry(
      key: json['key'] as String,
      displayName: json['displayName'] as String,
      baseUrl: json['baseUrl'] as String,
      auth: RegistryAuth.fromJson(json['auth'] as Map<String, dynamic>),
      deviceIdLabel: json['deviceIdLabel'] as String? ?? 'Device ID',
      deviceIdHint: json['deviceIdHint'] as String? ?? '',
      secretLabel: json['secretLabel'] as String? ?? 'API Key',
      secretHint: json['secretHint'] as String? ?? '',
      authKind: json['authKind'] as String? ?? 'apiKey',
      supportsHistory: json['supportsHistory'] as bool? ?? false,
      verified: json['verified'] as bool? ?? false,
      genericCompatible: json['genericCompatible'] as bool? ?? false,
      overrideBuiltin: json['overrideBuiltin'] as bool? ?? false,
      timeoutSeconds: (json['timeoutSeconds'] as num?)?.toInt() ?? 20,
      minPollIntervalSeconds:
          (json['minPollIntervalSeconds'] as num?)?.toInt() ?? 60,
      rateLimitNote: json['rateLimitNote'] as String? ?? '',
      fleetEndpoint: RegistryEndpoint.fromJson(
        json['fleet'] as Map<String, dynamic>,
      ),
      vehicleEndpoint: json['vehicle'] == null
          ? null
          : RegistryEndpoint.fromJson(json['vehicle'] as Map<String, dynamic>),
      historyEndpoint: json['history'] == null
          ? null
          : RegistryEndpoint.fromJson(
              json['history'] as Map<String, dynamic>,
            ),
      historyDeviceParam: json['historyDeviceParam'] == null
          ? null
          : RegistryHistoryDeviceParam.fromJson(
              json['historyDeviceParam'] as Map<String, dynamic>,
            ),
      fields: RegistryFieldMapping.fromJson(
        json['fields'] as Map<String, dynamic>,
      ),
      listPath: json['listPath'] as String?,
      locationField: json['locationField'] as String?,
      successCheck: json['successCheck'] == null
          ? null
          : RegistrySuccessCheck.fromJson(
              json['successCheck'] as Map<String, dynamic>,
            ),
      deviceMatching: json['deviceMatching'] as String? ?? 'strict',
    );
  }
}

/// How the provider authenticates.
class RegistryAuth {
  const RegistryAuth({
    required this.style,
    this.param,
    this.headerName,
    this.bodyField,
    this.secretFormat = 'single',
  });

  /// 'query' | 'header' | 'body' | 'none'.
  final String style;

  /// Query parameter name (style 'query'), e.g. 'authKey'.
  final String? param;

  /// Header name (style 'header'), e.g. 'x-api-key'.
  final String? headerName;

  /// Body field name (style 'body'), e.g. 'apikey'.
  final String? bodyField;

  /// How the saved secret splits up: 'single' (the whole secret),
  /// 'userId:secret' (userid:key), 'username:password'.
  final String secretFormat;

  factory RegistryAuth.fromJson(Map<String, dynamic> json) {
    return RegistryAuth(
      style: json['style'] as String? ?? 'none',
      param: json['param'] as String?,
      headerName: json['headerName'] as String?,
      bodyField: json['bodyField'] as String?,
      secretFormat: json['secretFormat'] as String? ?? 'single',
    );
  }
}

/// One endpoint: method + path, with optional query/body templates.
/// Placeholders such as {deviceId}, {secret}, {userId}, {apiKey},
/// {username}, {password}, {imei}, {fromEpoch}, {toEpoch}, {from},
/// {to} are substituted at request time.
class RegistryEndpoint {
  const RegistryEndpoint({
    required this.method,
    required this.path,
    this.query = const {},
    this.body,
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, dynamic>? body;

  factory RegistryEndpoint.fromJson(Map<String, dynamic> json) {
    final rawQuery = json['query'] as Map<String, dynamic>? ?? {};
    return RegistryEndpoint(
      method: (json['method'] as String? ?? 'GET').toUpperCase(),
      path: json['path'] as String,
      query: rawQuery.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      body: json['body'] as Map<String, dynamic>?,
    );
  }
}

/// History device-id parameter selection.
class RegistryHistoryDeviceParam {
  const RegistryHistoryDeviceParam({
    required this.vehicleIdParam,
    required this.imeiParam,
  });

  /// Parameter used when the device id is a short numeric id.
  final String vehicleIdParam;

  /// Parameter used otherwise (IMEI / registration).
  final String imeiParam;

  factory RegistryHistoryDeviceParam.fromJson(Map<String, dynamic> json) {
    return RegistryHistoryDeviceParam(
      vehicleIdParam: json['vehicleIdParam'] as String,
      imeiParam: json['imeiParam'] as String,
    );
  }
}

/// Field mapping: JSON paths (dot-separated) inside one vehicle item.
class RegistryFieldMapping {
  const RegistryFieldMapping({
    required this.id,
    required this.displayName,
    this.imei,
    this.latitude,
    this.longitude,
    this.speed,
    this.ignition,
    this.lastUpdated,
    this.trueValues = const [true, 'true', 'ON', 'on', '1', 1],
    this.falseValues = const [false, 'false', 'OFF', 'off', '0', 0],
  });

  final String id;
  final String displayName;
  final String? imei;
  final String? latitude;
  final String? longitude;
  final String? speed;
  final String? ignition;
  final String? lastUpdated;

  /// Raw values that mean "ignition on".
  final List<dynamic> trueValues;

  /// Raw values that mean "ignition off".
  final List<dynamic> falseValues;

  factory RegistryFieldMapping.fromJson(Map<String, dynamic> json) {
    return RegistryFieldMapping(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      imei: json['imei'] as String?,
      latitude: json['latitude'] as String?,
      longitude: json['longitude'] as String?,
      speed: json['speed'] as String?,
      ignition: json['ignition'] as String?,
      lastUpdated: json['lastUpdated'] as String?,
      trueValues:
          (json['trueValues'] as List<dynamic>?) ??
          const [true, 'true', 'ON', 'on', '1', 1],
      falseValues:
          (json['falseValues'] as List<dynamic>?) ??
          const [false, 'false', 'OFF', 'off', '0', 0],
    );
  }
}

/// Success check on the decoded response, e.g. Aargee's status == 1.
class RegistrySuccessCheck {
  const RegistrySuccessCheck({required this.field, required this.equals});

  final String field;
  final dynamic equals;

  factory RegistrySuccessCheck.fromJson(Map<String, dynamic> json) {
    return RegistrySuccessCheck(
      field: json['field'] as String,
      equals: json['equals'],
    );
  }
}

/// Parses registry JSON into a [ProviderRegistry].
///
/// Invalid entries are skipped (and listed in [ProviderRegistry.warnings])
/// instead of failing the whole file — one bad provider must never
/// break the others. Throws [FormatException] only when the file
/// itself is not JSON or has no usable `providers` list.
ProviderRegistry parseProviderRegistry(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Registry is not a JSON object.');
  }
  final version = (decoded['version'] as num?)?.toInt() ?? 1;
  final rawProviders = decoded['providers'];
  if (rawProviders is! List) {
    throw const FormatException('Registry has no "providers" list.');
  }
  final entries = <RegistryEntry>[];
  final warnings = <String>[];
  for (final raw in rawProviders) {
    if (raw is! Map<String, dynamic>) {
      warnings.add('Skipped a provider entry that is not an object.');
      continue;
    }
    try {
      final entry = RegistryEntry.fromJson(raw);
      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(entry.key)) {
        warnings.add('Skipped provider with invalid key "${entry.key}".');
        continue;
      }
      final uri = Uri.tryParse(entry.baseUrl);
      if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
        warnings.add(
          'Skipped provider "${entry.key}": bad baseUrl "${entry.baseUrl}".',
        );
        continue;
      }
      entries.add(entry);
    } catch (e) {
      warnings.add('Skipped a provider entry: $e');
    }
  }
  return ProviderRegistry(
    version: version,
    entries: entries,
    warnings: warnings,
  );
}
