import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/models/vehicle.dart';
import 'package:unitrack/models/vehicle_category.dart';
import 'package:unitrack/services/trip_playback.dart';

Vehicle _point(double lat, double lon, {double speed = 0}) {
  return Vehicle(
    id: 'KL01AB1234',
    displayName: 'KL01AB1234',
    providerKey: 'aargee',
    imei: 'KL01AB1234',
    latitude: lat,
    longitude: lon,
    speedKmph: speed,
    status: VehicleStatus.live,
    category: VehicleCategory.car,
  );
}

List<Vehicle> _route() => [
  _point(10.0, 76.0, speed: 10),
  _point(10.1, 76.1, speed: 20),
  _point(10.2, 76.2, speed: 30),
  _point(10.3, 76.3, speed: 40),
];

void main() {
  group('TripPlayback', () {
    test('starts at the first point with zero progress', () {
      final route = _route();
      final playback = TripPlayback(points: route);
      expect(playback.index, 0);
      expect(playback.current, same(route.first));
      expect(playback.progress, 0.0);
      expect(playback.isAtEnd, false);
      expect(playback.travelled.length, 1);
      expect(playback.remaining.length, 4);
    });

    test('advance steps one point at a time until the end', () {
      final playback = TripPlayback(points: _route());
      playback.advance();
      expect(playback.index, 1);
      expect(playback.progress, closeTo(1 / 3, 0.001));
      playback.advance();
      playback.advance();
      expect(playback.index, 3);
      expect(playback.isAtEnd, true);
      expect(playback.progress, 1.0);
      // Advancing past the end is a no-op.
      playback.advance();
      expect(playback.index, 3);
    });

    test('travelled and remaining split at the current index', () {
      final playback = TripPlayback(points: _route());
      playback.advance();
      playback.advance();
      expect(playback.travelled.length, 3);
      expect(playback.remaining.length, 2);
      // The current point belongs to both halves so the line is continuous.
      expect(playback.travelled.last, playback.remaining.first);
    });

    test('seek clamps to the route and restart goes back to the start', () {
      final playback = TripPlayback(points: _route());
      playback.seek(99);
      expect(playback.index, 3);
      playback.seek(-5);
      expect(playback.index, 0);
      playback.seek(2);
      expect(playback.index, 2);
      playback.restart();
      expect(playback.index, 0);
      expect(playback.isAtEnd, false);
    });

    test('step duration halves at 2x and quarters at 4x', () {
      final playback = TripPlayback(points: _route());
      expect(playback.stepDuration, const Duration(milliseconds: 500));
      playback.speedMultiplier = 2;
      expect(playback.stepDuration, const Duration(milliseconds: 250));
      playback.speedMultiplier = 4;
      expect(playback.stepDuration, const Duration(milliseconds: 125));
    });

    test('invalid speed multipliers are rejected', () {
      final playback = TripPlayback(points: _route());
      expect(() => playback.speedMultiplier = 3, throwsArgumentError);
      expect(() => playback.speedMultiplier = 0.5, throwsArgumentError);
      expect(playback.speedMultiplier, 1.0);
    });

    test('a single-point route is already at the end', () {
      final playback = TripPlayback(points: [_point(10.0, 76.0)]);
      expect(playback.isAtEnd, true);
      expect(playback.progress, 1.0);
      playback.advance();
      expect(playback.index, 0);
    });

    test('an empty route throws', () {
      expect(() => TripPlayback(points: []), throwsArgumentError);
    });

    test('speeds list is 1x, 2x, 4x', () {
      expect(TripPlayback.speeds, [1.0, 2.0, 4.0]);
    });
  });
}
