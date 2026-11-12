/// A fleet event detected locally from poll snapshots (ignition
/// transitions, overspeed, geofence enter/exit).
///
/// Alerts are stored in SharedPreferences (see [AlertsNotifier]),
/// newest first, capped at 100. No provider reports SOS, so there is
/// no SOS alert type — the UI must not invent one.
enum AlertType {
  ignitionOn,
  ignitionOff,
  overspeed,
  geofenceEnter,
  geofenceExit,
}

/// How urgent an alert is. Ignition changes are informational (low);
/// overspeed is medium, or high when far over the limit; geofence
/// crossings are medium.
enum AlertSeverity { low, medium, high }

class FleetAlert {
  const FleetAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.vehicleKey,
    required this.vehicleName,
    required this.time,
    this.latitude,
    this.longitude,
    this.message,
    this.speedKmph,
    this.geofenceName,
  });

  /// Unique id: `<epochMs>-<type>-<vehicleKey>`.
  final String id;

  final AlertType type;
  final AlertSeverity severity;

  /// `<providerKey>:<vehicleId>`, as in [vehicleKey].
  final String vehicleKey;

  /// Registration / display name at detection time.
  final String vehicleName;

  final DateTime time;
  final double? latitude;
  final double? longitude;

  /// Extra detail, e.g. 'Speed 96 km/h — limit 80 km/h'.
  final String? message;

  /// Speed at detection time, for overspeed alerts.
  final double? speedKmph;

  /// Geofence name, for geofence alerts.
  final String? geofenceName;

  /// Volty-style title: "Ignition Off - KL13AG1293".
  String get title {
    final label = switch (type) {
      AlertType.ignitionOn => 'Ignition On',
      AlertType.ignitionOff => 'Ignition Off',
      AlertType.overspeed => 'Overspeed',
      AlertType.geofenceEnter => 'Entered geofence',
      AlertType.geofenceExit => 'Left geofence',
    };
    return '$label - $vehicleName';
  }

  String get severityLabel => switch (severity) {
    AlertSeverity.low => 'low',
    AlertSeverity.medium => 'medium',
    AlertSeverity.high => 'high',
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'severity': severity.name,
    'vehicleKey': vehicleKey,
    'vehicleName': vehicleName,
    'time': time.millisecondsSinceEpoch,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (message != null) 'message': message,
    if (speedKmph != null) 'speedKmph': speedKmph,
    if (geofenceName != null) 'geofenceName': geofenceName,
  };

  factory FleetAlert.fromJson(Map<String, dynamic> json) {
    return FleetAlert(
      id: json['id'] as String,
      type: AlertType.values.byName(json['type'] as String),
      severity: AlertSeverity.values.byName(json['severity'] as String),
      vehicleKey: json['vehicleKey'] as String,
      vehicleName: json['vehicleName'] as String,
      time: DateTime.fromMillisecondsSinceEpoch(json['time'] as int),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      message: json['message'] as String?,
      speedKmph: (json['speedKmph'] as num?)?.toDouble(),
      geofenceName: json['geofenceName'] as String?,
    );
  }
}
