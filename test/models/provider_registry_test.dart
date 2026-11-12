import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/models/gps_provider.dart';
import 'package:unitrack/models/provider_registry.dart';

void main() {
  group('parseProviderRegistry', () {
    test('parses the shipped registry.json: all 8 providers', () {
      final file = File('providers/registry.json');
      expect(file.existsSync(), isTrue, reason: 'run from the repo root');
      final registry = parseProviderRegistry(file.readAsStringSync());
      expect(registry.version, 2);
      expect(registry.entries, hasLength(8));
      expect(
        registry.entries.map((e) => e.key).toSet(),
        {
          'transight',
          'aargee',
          'radiant',
          'mercydatrack',
          'mercydatrack4g',
          'pauldeatrack',
          'voltysoft',
          'hashtrace',
        },
      );
      // No real credential values anywhere — secrets appear only as
      // placeholders ({secret}, {userId}, ...).
      final raw = file.readAsStringSync();
      expect(raw, contains('{secret}'));
      expect(raw, isNot(contains('{authKey}')));
      for (final entry in registry.entries) {
        expect(entry.baseUrl, isNotEmpty);
        expect(entry.fleetEndpoint.path, isNotEmpty);
        expect(entry.fields.id, isNotEmpty);
        expect(entry.fields.displayName, isNotEmpty);
      }
      // HashTrace: query-param auth, string lat/lon.
      final hashTrace = registry.entryFor('hashtrace')!;
      expect(hashTrace.auth.style, 'query');
      expect(hashTrace.auth.param, 'authKey');
      expect(hashTrace.fields.latitude, 'Lat');
      expect(hashTrace.supportsHistory, isFalse);
      // Aargee: apikey in the POST body, nested data list.
      final aargee = registry.entryFor('aargee')!;
      expect(aargee.auth.style, 'body');
      expect(aargee.listPath, 'data');
      expect(aargee.locationField, 'location');
      expect(aargee.supportsHistory, isTrue);
      // SimplyTrack: header auth, NOT generic-compatible (its history
      // path uses epoch ranges the generic client must not guess).
      final simply = registry.entryFor('voltysoft')!;
      expect(simply.auth.style, 'header');
      expect(simply.genericCompatible, isFalse);
      // LiveTrace is http — the generic client must never serve it.
      final liveTrace = registry.entryFor('radiant')!;
      expect(liveTrace.isHttps, isFalse);
      expect(liveTrace.listPath, 'response.LiveData');
    });

    test('invalid entries are skipped, the rest still load', () {
      const raw = '''
{
  "version": 3,
  "providers": [
    {"key": "good", "displayName": "Good", "baseUrl": "https://example.com",
     "auth": {"style": "query", "param": "key", "secretFormat": "key"},
     "fleet": {"method": "GET", "path": "/fleet"},
     "fields": {"id": "id", "displayName": "name"}},
    {"key": "no-base-url", "displayName": "Bad"},
    {"displayName": "No key at all"}
  ]
}
''';
      final registry = parseProviderRegistry(raw);
      expect(registry.version, 3);
      expect(registry.entries.map((e) => e.key), ['good']);
    });

    test('bad JSON throws a FormatException', () {
      expect(() => parseProviderRegistry('not json'), throwsFormatException);
    });
  });

  group('override rules', () {
    ProviderRegistry registryWith({
      required bool genericCompatible,
      required bool overrideBuiltin,
      required String baseUrl,
    }) {
      return parseProviderRegistry('''
{
  "version": 1,
  "providers": [
    {"key": "aargee", "displayName": "Aargee", "baseUrl": "$baseUrl",
     "auth": {"style": "body", "bodyField": "apikey", "secretFormat": "key"},
     "genericCompatible": $genericCompatible,
     "overrideBuiltin": $overrideBuiltin,
     "fleet": {"method": "GET", "path": "/fleet"},
     "fields": {"id": "id", "displayName": "name"}}
  ]
}
''');
    }

    test('override only when generic-compatible + override + https', () {
      expect(
        registryWith(
          genericCompatible: true,
          overrideBuiltin: true,
          baseUrl: 'https://example.com',
        ).overrideFor('aargee'),
        isNotNull,
      );
      expect(
        registryWith(
          genericCompatible: false,
          overrideBuiltin: true,
          baseUrl: 'https://example.com',
        ).overrideFor('aargee'),
        isNull,
      );
      expect(
        registryWith(
          genericCompatible: true,
          overrideBuiltin: false,
          baseUrl: 'https://example.com',
        ).overrideFor('aargee'),
        isNull,
      );
      expect(
        registryWith(
          genericCompatible: true,
          overrideBuiltin: true,
          baseUrl: 'http://example.com',
        ).overrideFor('aargee'),
        isNull,
      );
    });

    test('newProviders lists only non-built-in https entries', () {
      const raw = '''
{
  "version": 1,
  "providers": [
    {"key": "aargee", "displayName": "Aargee", "baseUrl": "https://a.example.com",
     "auth": {"style": "body", "bodyField": "apikey", "secretFormat": "key"},
     "fleet": {"method": "GET", "path": "/fleet"},
     "fields": {"id": "id", "displayName": "name"}},
    {"key": "mercydatrack4g", "displayName": "MercyDataTrack (4G)", "baseUrl": "https://proconsole.mercydatrack.com/mtrack",
     "auth": {"style": "query", "param": "username", "secretFormat": "username:password"},
     "fleet": {"method": "GET", "path": "/vehicle-data"},
     "fields": {"id": "id", "displayName": "name"}},
    {"key": "newco", "displayName": "NewCo", "baseUrl": "https://new.example.com",
     "auth": {"style": "query", "param": "key", "secretFormat": "key"},
     "fleet": {"method": "GET", "path": "/fleet"},
     "fields": {"id": "id", "displayName": "name"}},
    {"key": "plainhttp", "displayName": "Plain", "baseUrl": "http://p.example.com",
     "auth": {"style": "query", "param": "key", "secretFormat": "key"},
     "fleet": {"method": "GET", "path": "/fleet"},
     "fields": {"id": "id", "displayName": "name"}}
  ]
}
''';
      final registry = parseProviderRegistry(raw);
      // Regression (v1.2.0): the registry's mercydatrack4g entry leaked
      // into newProviders as a "Remote" duplicate of the built-in,
      // because the built-in key set was hardcoded with only 7 keys.
      expect(registry.newProviders.map((e) => e.key), ['newco']);
    });

    test('newProviders stays empty when the registry lists every built-in', () {
      final keys = GpsProvider.values.map((p) => p.key).toList();
      final entries = keys
          .map(
            (key) =>
                '{"key": "$key", "displayName": "$key", "baseUrl": "https://x.example.com", '
                '"auth": {"style": "query", "param": "key", "secretFormat": "key"}, '
                '"fleet": {"method": "GET", "path": "/fleet"}, '
                '"fields": {"id": "id", "displayName": "name"}}',
          )
          .join(',\n    ');
      final registry = parseProviderRegistry(
        '{"version": 2, "providers": [$entries]}',
      );
      expect(registry.newProviders, isEmpty);
    });
  });
}
