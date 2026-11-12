import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/gps_provider.dart';
import '../../models/provider_credentials.dart';
import '../../models/provider_registry.dart';
import '../../models/vehicle.dart';
import '../../utils/parsing.dart';
import 'gps_provider_client.dart';

/// A provider client driven purely by a [RegistryEntry]: it builds the
/// request from the entry's endpoints and auth style, and parses the
/// response through the entry's field mappings.
///
/// This is what serves registry-added providers (and, only when an
/// entry is marked `overrideBuiltin` + `genericCompatible` with an
/// https base URL, a built-in provider's replacement — see
/// providers/README.md). The 7 built-in clients stay the fallback
/// and are never replaced by an entry that fails those checks.
///
/// Credentials are only ever sent to the entry's own baseUrl.
class RemoteProviderClient extends GpsProviderClient {
  RemoteProviderClient(this.entry, {this.httpClient});

  final RegistryEntry entry;

  /// Test-only HTTP client override (MockClient in tests). When null,
  /// a fresh [http.Client] is created per call and closed after.
  final http.Client? httpClient;

  @override
  GpsProvider? get provider => null;

  @override
  String get providerKey => entry.key;

  @override
  String get providerDisplayName => entry.displayName;

  @override
  bool get supportsHistory =>
      entry.supportsHistory && entry.historyEndpoint != null;

  @override
  Duration get minimumPollInterval =>
      Duration(seconds: entry.minPollIntervalSeconds);

  /// Splits the saved secret into the parts the entry's auth style
  /// needs. Public for tests.
  static Map<String, String> resolveAuthParts(
    RegistryEntry entry,
    ProviderCredentials credentials,
  ) {
    final secret = credentials.secret.trim();
    final deviceId = credentials.deviceId.trim();
    final parts = <String, String>{
      'deviceId': deviceId,
      'secret': secret,
      'apiKey': secret,
    };
    switch (entry.auth.secretFormat) {
      case 'userId:secret':
        if (secret.contains(':')) {
          final split = secret.split(':');
          parts['userId'] = split.first;
          parts['secret'] = split.sublist(1).join(':');
          parts['apiKey'] = parts['secret']!;
        } else {
          parts['userId'] = deviceId;
        }
      case 'username:password':
        final colon = secret.indexOf(':');
        if (colon > 0) {
          parts['username'] = secret.substring(0, colon);
          parts['password'] = secret.substring(colon + 1);
        } else {
          parts['username'] = secret;
          parts['password'] = '';
        }
      default:
        parts['userId'] = deviceId;
    }
    // IMEI placeholder: deviceId after a "userId:imei" split, else the
    // deviceId itself (SimplyTrack-style credentials).
    if (deviceId.contains(':')) {
      parts['imei'] = deviceId.split(':').sublist(1).join(':');
      parts['userId'] = deviceId.split(':').first;
    } else if (secret.contains(':') &&
        entry.auth.secretFormat == 'userId:secret') {
      parts['imei'] = deviceId;
    } else {
      parts['imei'] = deviceId;
    }
    return parts;
  }

  /// Replaces `{placeholder}` tokens in [template] with [parts].
  /// Public for tests.
  static String substitute(String template, Map<String, String> parts) {
    return template.replaceAllMapped(
      RegExp(r'\{(\w+)\}'),
      (match) => parts[match.group(1)] ?? match.group(0)!,
    );
  }

  /// Deep-substitutes placeholders in a JSON body template.
  static dynamic substituteDeep(
    dynamic template,
    Map<String, String> parts,
  ) {
    if (template is String) return substitute(template, parts);
    if (template is Map<String, dynamic>) {
      return template.map(
        (key, value) => MapEntry(key, substituteDeep(value, parts)),
      );
    }
    if (template is List) {
      return template.map((value) => substituteDeep(value, parts)).toList();
    }
    return template;
  }

  /// Reads a dot-separated path (e.g. "response.LiveData" or "VId")
  /// out of decoded JSON. Returns null when any step is missing.
  static dynamic readPath(dynamic json, String? path) {
    if (path == null || path.isEmpty) return json;
    dynamic current = json;
    for (final segment in path.split('.')) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
      } else if (current is List) {
        final index = int.tryParse(segment);
        if (index == null || index < 0 || index >= current.length) {
          return null;
        }
        current = current[index];
      } else {
        return null;
      }
      if (current == null) return null;
    }
    return current;
  }

  bool _matchesIgnition(dynamic value, List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (value is String && candidate is String) {
        if (value.trim().toLowerCase() == candidate.toLowerCase()) {
          return true;
        }
      } else if (value == candidate) {
        return true;
      }
    }
    return false;
  }

  bool? _parseIgnitionValue(dynamic value) {
    if (value == null) return null;
    if (_matchesIgnition(value, entry.fields.trueValues)) return true;
    if (_matchesIgnition(value, entry.fields.falseValues)) return false;
    return parseIgnition(value);
  }

  Vehicle _parseVehicle(Map<String, dynamic> json) {
    final fields = entry.fields;
    double? lat;
    double? lon;
    if (entry.locationField != null) {
      final raw = readPath(json, entry.locationField)?.toString() ?? '';
      final parts = raw.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        lat = double.tryParse(parts[0]);
        lon = double.tryParse(parts[1]);
      }
    } else {
      lat = parseCoord(readPath(json, fields.latitude));
      lon = parseCoord(readPath(json, fields.longitude));
    }
    final ignition = _parseIgnitionValue(readPath(json, fields.ignition));
    final timeRaw = readPath(json, fields.lastUpdated)?.toString() ?? '';
    final id = readPath(json, fields.id)?.toString() ?? 'unknown';
    final name =
        readPath(json, fields.displayName)?.toString() ?? id;
    return Vehicle(
      id: id,
      displayName: name,
      providerKey: entry.key,
      imei: readPath(json, fields.imei)?.toString(),
      latitude: lat,
      longitude: lon,
      speedKmph: parseSpeed(readPath(json, fields.speed)),
      ignition: ignition,
      lastUpdatedRaw: timeRaw,
      lastUpdated:
          parseDateTime(timeRaw) ?? parseDayMonthYearTime(timeRaw),
      status: ignition == true
          ? VehicleStatus.live
          : ignition == false
          ? VehicleStatus.idle
          : VehicleStatus.unknown,
      rawJson: json,
    );
  }

  List<Vehicle> _parseList(dynamic decoded) {
    final raw = readPath(decoded, entry.listPath);
    final List<dynamic> items;
    if (raw is List) {
      items = raw;
    } else if (raw is Map<String, dynamic>) {
      items = [raw];
    } else {
      return const [];
    }
    return items.whereType<Map<String, dynamic>>().map(_parseVehicle).toList();
  }

  Future<List<Vehicle>> _call(
    RegistryEndpoint endpoint,
    ProviderCredentials credentials, {
    required Map<String, String> extraParts,
    http.Client? httpClient,
  }) async {
    final parts = {
      ...resolveAuthParts(entry, credentials),
      ...extraParts,
    };
    final client = httpClient ?? this.httpClient ?? http.Client();
    try {
      final base = entry.baseUrl.endsWith('/')
          ? entry.baseUrl.substring(0, entry.baseUrl.length - 1)
          : entry.baseUrl;
      final path = substitute(endpoint.path, parts);
      final uri = Uri.parse('$base/$path').replace(
        queryParameters: endpoint.query.isEmpty
            ? null
            : endpoint.query.map(
                (key, value) => MapEntry(key, substitute(value, parts)),
              ),
      );
      final headers = <String, String>{};
      if (entry.auth.style == 'header' && entry.auth.headerName != null) {
        headers[entry.auth.headerName!] = substitute(
          '{secret}',
          parts,
        );
      }
      http.Response response;
      final timeout = Duration(seconds: entry.timeoutSeconds);
      if (endpoint.method == 'POST') {
        headers['Content-Type'] = 'application/json';
        final body = endpoint.body == null
            ? null
            : jsonEncode(substituteDeep(endpoint.body, parts));
        response = await client
            .post(uri, headers: headers, body: body)
            .timeout(timeout);
      } else {
        response = await client.get(uri, headers: headers).timeout(timeout);
      }
      if (response.statusCode != 200) {
        throw ProviderException(
          '${entry.displayName} returned HTTP ${response.statusCode}.',
        );
      }
      final decoded = jsonDecode(response.body);
      final check = entry.successCheck;
      if (check != null && decoded is Map<String, dynamic>) {
        final actual = readPath(decoded, check.field);
        if (actual != check.equals) {
          throw ProviderException(
            '${entry.displayName} reported an error '
            '(status $actual).',
          );
        }
      }
      return _parseList(decoded);
    } finally {
      if (httpClient == null && this.httpClient == null) client.close();
    }
  }

  @override
  Future<List<Vehicle>> fetchLiveVehicles(
    ProviderCredentials credentials, {
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? this.httpClient;
    // Prefer the single-vehicle endpoint when the entry has one and
    // the device id is given — it proves THAT vehicle exists.
    final endpoint = entry.vehicleEndpoint != null &&
            credentials.deviceId.trim().isNotEmpty
        ? entry.vehicleEndpoint!
        : entry.fleetEndpoint;
    final vehicles = await _call(
      endpoint,
      credentials,
      extraParts: const {},
      httpClient: client,
    );
    if (entry.deviceMatching == 'fleet') return vehicles;
    final deviceId = credentials.deviceId.trim();
    if (deviceId.isEmpty) return vehicles;
    final match = vehicles
        .where(
          (v) =>
              v.id == deviceId ||
              v.imei == deviceId ||
              v.displayName == deviceId,
        )
        .toList();
    if (match.isEmpty) {
      throw ProviderException(
        '${entry.displayName} found no vehicle with ID "$deviceId" — '
        'check the device ID.',
      );
    }
    return match;
  }

  @override
  Future<List<Vehicle>> fetchHistory(
    ProviderCredentials credentials, {
    required DateTime from,
    required DateTime to,
    http.Client? httpClient,
  }) async {
    final endpoint = entry.historyEndpoint;
    if (endpoint == null) {
      throw UnsupportedError(
        '${entry.displayName} does not support history — '
        'it returns live snapshots only.',
      );
    }
    final extra = <String, String>{
      'fromEpoch': '${from.millisecondsSinceEpoch ~/ 1000}',
      'toEpoch': '${to.millisecondsSinceEpoch ~/ 1000}',
      'from': _formatDateTime(from),
      'to': _formatDateTime(to),
    };
    final deviceParam = entry.historyDeviceParam;
    if (deviceParam != null) {
      final deviceId = credentials.deviceId.trim();
      final numeric =
          deviceId.length < 10 && int.tryParse(deviceId) != null;
      extra[deviceParam.vehicleIdParam] = numeric ? deviceId : '';
      extra[deviceParam.imeiParam] = numeric ? '' : deviceId;
    }
    return _call(
      endpoint,
      credentials,
      extraParts: extra,
      httpClient: httpClient ?? this.httpClient,
    );
  }

  static String _formatDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }
}
