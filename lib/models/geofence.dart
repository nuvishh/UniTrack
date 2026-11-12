/// A circular geofence around a point, attached to one vehicle.
///
/// Created from a vehicle's detail screen (at its current location)
/// and stored in SharedPreferences (see [GeofenceNotifier]). The
/// alert detector watches poll snapshots for enter/exit crossings.
class Geofence {
  const Geofence({
    required this.id,
    required this.vehicleKey,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
  });

  /// Unique id: milliseconds since epoch at creation.
  final String id;

  /// `<providerKey>:<vehicleId>` of the vehicle it watches.
  final String vehicleKey;

  final String name;
  final double latitude;
  final double longitude;

  /// Radius in metres.
  final double radiusM;

  String get radiusLabel =>
      radiusM >= 1000
          ? '${(radiusM / 1000).toStringAsFixed(1)} km'
          : '${radiusM.toStringAsFixed(0)} m';

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleKey': vehicleKey,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'radiusM': radiusM,
  };

  factory Geofence.fromJson(Map<String, dynamic> json) {
    return Geofence(
      id: json['id'] as String,
      vehicleKey: json['vehicleKey'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusM: (json['radiusM'] as num).toDouble(),
    );
  }
}
