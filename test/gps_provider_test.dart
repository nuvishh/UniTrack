import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/models/gps_provider.dart';
import 'package:unitrack/services/providers/aargee_client.dart';
import 'package:unitrack/services/providers/hashtrace_client.dart';
import 'package:unitrack/services/providers/livetrace_client.dart';
import 'package:unitrack/services/providers/mercydatrack_client.dart';
import 'package:unitrack/services/providers/pauldeatrack_client.dart';
import 'package:unitrack/services/providers/provider_client_factory.dart';
import 'package:unitrack/services/providers/simplytrack_client.dart';
import 'package:unitrack/services/providers/transight_client.dart';

void main() {
  group('GpsProvider', () {
    test('all 8 provider keys resolve', () {
      const keys = [
        'transight',
        'aargee',
        'radiant',
        'mercydatrack',
        'mercydatrack4g',
        'pauldeatrack',
        'voltysoft',
        'hashtrace',
      ];
      expect(GpsProvider.values, hasLength(8));
      for (final key in keys) {
        expect(GpsProvider.fromKey(key).key, key);
      }
    });

    test('unknown key throws ArgumentError', () {
      expect(() => GpsProvider.fromKey('nope'), throwsArgumentError);
    });

    test('only live-snapshot providers lack history support', () {
      // Live snapshots only: HashTrace, LiveTrace, MercyDataTrack and
      // PauldeaTrack (no history endpoint verified for the last two),
      // plus MercyDataTrack (4G), whose endpoint returns today's
      // track but no server-side history API.
      expect(GpsProvider.hashtrace.supportsHistory, isFalse);
      expect(GpsProvider.radiant.supportsHistory, isFalse);
      expect(GpsProvider.mercydatrack.supportsHistory, isFalse);
      expect(GpsProvider.mercydatrack4g.supportsHistory, isFalse);
      expect(GpsProvider.pauldeatrack.supportsHistory, isFalse);
      for (final provider in GpsProvider.values) {
        if (provider != GpsProvider.hashtrace &&
            provider != GpsProvider.radiant &&
            provider != GpsProvider.mercydatrack &&
            provider != GpsProvider.mercydatrack4g &&
            provider != GpsProvider.pauldeatrack) {
          expect(
            provider.supportsHistory,
            isTrue,
            reason: '${provider.key} should support history',
          );
        }
      }
    });

    test('rate-limited providers never poll faster than 60s', () {
      expect(
        GpsProvider.voltysoft.minPollInterval.inSeconds,
        greaterThanOrEqualTo(60),
      );
      expect(
        GpsProvider.aargee.minPollInterval.inSeconds,
        greaterThanOrEqualTo(60),
      );
    });

    test('verified flags match the live checks', () {
      // Verified live 2026-11-09: LiveTrace, SimplyTrack, HashTrace,
      // Aargee. Verified live 2026-11-11: MercyDataTrack, PauldeaTrack,
      // Transight. All 7 providers are now live-verified.
      expect(GpsProvider.radiant.verified, isTrue);
      expect(GpsProvider.voltysoft.verified, isTrue);
      expect(GpsProvider.hashtrace.verified, isTrue);
      expect(GpsProvider.aargee.verified, isTrue);
      expect(GpsProvider.mercydatrack.verified, isTrue);
      expect(GpsProvider.pauldeatrack.verified, isTrue);
      expect(GpsProvider.transight.verified, isTrue);
    });
  });

  group('provider_client_factory', () {
    test('returns the right client type for every provider key', () {
      expect(clientForKey('transight'), isA<TransightClient>());
      expect(clientForKey('aargee'), isA<AargeeClient>());
      expect(clientForKey('radiant'), isA<LiveTraceClient>());
      expect(clientForKey('mercydatrack'), isA<MercyDataTrackClient>());
      expect(clientForKey('pauldeatrack'), isA<PauldeaTrackClient>());
      expect(clientForKey('voltysoft'), isA<SimplyTrackClient>());
      expect(clientForKey('hashtrace'), isA<HashTraceClient>());
    });
  });
}
