import 'dart:math';

/// Geography helpers for UniTrack's reports and geofences.
///
/// Pure functions — no Flutter, no I/O — so they are unit-tested
/// directly (see test/geo_test.dart).
const double earthRadiusKm = 6371.0;

/// Great-circle distance between two points, in kilometres.
double haversineKm(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) *
          cos(_toRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

double _toRadians(double degrees) => degrees * pi / 180;

/// True when the point is within [radiusM] metres of the centre.
bool isWithinRadiusM(
  double lat,
  double lon,
  double centreLat,
  double centreLon,
  double radiusM,
) => haversineKm(lat, lon, centreLat, centreLon) * 1000 <= radiusM;

/// Human distance: "850 m" under 1 km, "21.5 km" above.
String formatDistanceKm(double km) {
  if (km < 1) return '${(km * 1000).toStringAsFixed(0)} m';
  return '${km.toStringAsFixed(1)} km';
}

/// Human duration: "1h 20m", "45m", "30s".
String formatDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  if (totalMinutes >= 60) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  if (totalMinutes >= 1) return '${totalMinutes}m';
  return '${duration.inSeconds}s';
}
