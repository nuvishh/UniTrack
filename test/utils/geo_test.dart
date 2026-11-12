import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/utils/geo.dart';

void main() {
  group('haversineKm', () {
    test('same point is zero', () {
      expect(haversineKm(12.5, 75.0, 12.5, 75.0), 0);
    });

    test('known distance: ~1.11 km per 0.01 degree of latitude', () {
      // 0.01° latitude ≈ 1.11 km everywhere.
      final km = haversineKm(12.0, 75.0, 12.01, 75.0);
      expect(km, closeTo(1.11, 0.01));
    });

    test('Kannur to Thalassery is roughly 20 km', () {
      // Kannur (11.8745, 75.3704) to Thalassery (11.7492, 75.4891).
      final km = haversineKm(11.8745, 75.3704, 11.7492, 75.4891);
      expect(km, closeTo(19.2, 1.0));
    });
  });

  group('isWithinRadiusM', () {
    test('inside and outside a 250 m geofence', () {
      // ~111 m north of the centre.
      expect(isWithinRadiusM(12.0, 75.0, 12.001, 75.0, 250), isTrue);
      // ~1.1 km north of the centre.
      expect(isWithinRadiusM(12.0, 75.0, 12.01, 75.0, 250), isFalse);
    });
  });

  group('formatDistanceKm', () {
    test('formats under 1 km as metres', () {
      expect(formatDistanceKm(0.45), '450 m');
    });

    test('formats 21.5 km with one decimal', () {
      expect(formatDistanceKm(21.5), '21.5 km');
    });
  });

  group('formatDuration', () {
    test('1h 20m like the Volty day summary', () {
      expect(formatDuration(const Duration(hours: 1, minutes: 20)), '1h 20m');
    });

    test('under an hour shows minutes only', () {
      expect(formatDuration(const Duration(minutes: 45)), '45m');
    });

    test('zero', () {
      expect(formatDuration(Duration.zero), '0s');
    });
  });
}
