/// One recorded position of a vehicle, from a poll snapshot.
///
/// The trip log (see [TripLogNotifier]) appends one of these per vehicle
/// per poll, so day reports work even for providers that return live
/// snapshots only. Stored compactly as a JSON array
/// `[epochMs, lat, lon, speedKmph, ignition]` to keep the
/// SharedPreferences payload small.
class TripPoint {
  const TripPoint({
    required this.time,
    required this.latitude,
    required this.longitude,
    this.speedKmph,
    this.ignition,
  });

  final DateTime time;
  final double latitude;
  final double longitude;
  final double? speedKmph;
  final bool? ignition;

  /// Compact JSON encoding: [epochMs, lat, lon, speed, ignition(1/0)].
  List<dynamic> toJson() => [
    time.millisecondsSinceEpoch,
    latitude,
    longitude,
    speedKmph,
    ignition == null ? null : (ignition! ? 1 : 0),
  ];

  factory TripPoint.fromJson(dynamic json) {
    final list = json as List<dynamic>;
    return TripPoint(
      time: DateTime.fromMillisecondsSinceEpoch(list[0] as int),
      latitude: (list[1] as num).toDouble(),
      longitude: (list[2] as num).toDouble(),
      speedKmph: list[3] == null ? null : (list[3] as num).toDouble(),
      ignition: list[4] == null ? null : list[4] == 1,
    );
  }
}

/// Key that identifies a vehicle across providers, matching the
/// Tracker's de-duplication: `<providerKey>:<vehicleId>`.
String vehicleKey(String providerKey, String vehicleId) =>
    '$providerKey:$vehicleId';
