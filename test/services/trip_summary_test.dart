import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/models/trip_point.dart';
import 'package:unitrack/services/trip_summary.dart';

TripPoint _point(
  int minutes,
  double lat,
  double lon,
  double speed,
  bool? ignition,
) {
  return TripPoint(
    time: DateTime(2026, 11, 12, 9, 0).add(Duration(minutes: minutes)),
    latitude: lat,
    longitude: lon,
    speedKmph: speed,
    ignition: ignition,
  );
}

void main() {
  group('computeDaySummary', () {
    final day = DateTime(2026, 11, 12);

    test('empty log is a zero summary', () {
      final summary = computeDaySummary(const [], day);
      expect(summary.distanceKm, 0);
      expect(summary.driving, Duration.zero);
      expect(summary.idling, Duration.zero);
      expect(summary.stopped, Duration.zero);
      expect(summary.points, 0);
    });

    test('driving + idling + stopped split by speed and ignition', () {
      // Segments are attributed to the START point's state: 0→10 and
      // 10→20 driving (start points moving), 20→30 idling (ignition
      // on, speed 0), 30→40 stopped (ignition off).
      final points = <TripPoint>[
        _point(0, 12.000, 75.000, 60, true),
        _point(10, 12.010, 75.000, 60, true),
        _point(20, 12.010, 75.000, 0, true),
        _point(30, 12.010, 75.000, 0, false),
        _point(40, 12.010, 75.000, 0, false),
      ];
      final summary = computeDaySummary(points, day);
      expect(summary.points, 5);
      expect(summary.distanceKm, closeTo(1.11, 0.05));
      expect(summary.driving, const Duration(minutes: 20));
      expect(summary.idling, const Duration(minutes: 10));
      expect(summary.stopped, const Duration(minutes: 10));
    });

    test('ignition unknown counts as stopped time', () {
      final points = [
        _point(0, 12.0, 75.0, 0, null),
        _point(5, 12.0, 75.0, 0, null),
      ];
      final summary = computeDaySummary(points, day);
      expect(summary.stopped, const Duration(minutes: 5));
    });

    test('gaps longer than 10 minutes are skipped, not guessed', () {
      final points = [
        _point(0, 12.0, 75.0, 60, true),
        // 60-minute gap — the state in between is unknown, so no
        // driving time is attributed to it.
        _point(60, 12.01, 75.0, 60, true),
      ];
      final summary = computeDaySummary(points, day);
      expect(summary.driving, Duration.zero);
      // Distance is still counted (capped at 5 km per segment), so a
      // teleport cannot inflate the day's distance.
      expect(summary.distanceKm, closeTo(1.11, 0.05));
    });

    test('points from another day are ignored', () {
      final points = [
        _point(0, 12.0, 75.0, 60, true),
        TripPoint(
          time: DateTime(2026, 11, 11, 9, 0),
          latitude: 12.0,
          longitude: 75.0,
          speedKmph: 60,
          ignition: true,
        ),
      ];
      final summary = computeDaySummary(points, day);
      expect(summary.points, 1);
    });
  });

  group('daySummaryCsv', () {
    test('header + summary + point rows', () {
      final day = DateTime(2026, 11, 12);
      final points = [
        _point(0, 12.0, 75.0, 60, true),
        _point(10, 12.01, 75.0, 0, false),
      ];
      final summary = computeDaySummary(points, day);
      final csv = daySummaryCsv(
        vehicleName: 'KL00XX0000',
        summary: summary,
        points: points,
      );
      expect(csv, contains('UniTrack day report — KL00XX0000'));
      expect(csv, contains('Total distance (km)'));
      expect(csv, contains('Driving time (min),10'));
      expect(csv, contains('Time,Latitude,Longitude,Speed (km/h),Ignition'));
      expect(csv, contains('12.0,75.0,60.0,on'));
    });
  });
}
