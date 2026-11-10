/// Live state of a vehicle, derived from its latest provider snapshot.
enum VehicleStatus {
  /// Ignition on (or provider reports the vehicle as moving/active).
  live,

  /// Ignition off / stopped.
  idle,

  /// No ignition information, or the provider reports it unreachable.
  unknown,

  /// The provider reports this vehicle as expired/unknown (HashTrace
  /// `_Expired` sentinel). Never plot such a vehicle on the map.
  expired,
}

/// One vehicle, in UniTrack's provider-neutral shape.
///
/// Every provider client converts its own JSON into this model, so the UI
/// never deals with provider-specific field names.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.displayName,
    required this.providerKey,
    this.imei,
    this.latitude,
    this.longitude,
    this.speedKmph,
    this.ignition,
    this.lastUpdatedRaw = '',
    this.lastUpdated,
    this.status = VehicleStatus.unknown,
    this.rawJson = const {},
  });

  /// Stable provider-local id: IMEI, numeric vehicle id (VId), or reg no.
  /// Combined with [providerKey] it uniquely identifies the vehicle.
  final String id;

  /// Registration number / plate, or the provider's vehicle name when no
  /// plate is available.
  final String displayName;

  /// Provider key, e.g. 'aargee', 'hashtrace' (see [GpsProvider]).
  final String providerKey;

  /// Device IMEI when the provider reports one.
  final String? imei;

  final double? latitude;
  final double? longitude;

  /// Speed in km/h when the provider reports it.
  final double? speedKmph;

  /// Ignition state when the provider reports it.
  final bool? ignition;

  /// The provider's timestamp exactly as received (kept because several
  /// providers omit the timezone — see [lastUpdated]).
  final String lastUpdatedRaw;

  /// Parsed [lastUpdatedRaw], or null when it could not be parsed.
  final DateTime? lastUpdated;

  final VehicleStatus status;

  /// The provider's original JSON object, for debugging.
  final Map<String, dynamic> rawJson;

  /// True when the vehicle has a real fix. (0, 0) is never a real fix —
  /// providers use it as a placeholder, and the HashTrace `_Expired`
  /// sentinel also sits at 0, 0.
  bool get hasFix =>
      latitude != null &&
      longitude != null &&
      !(latitude == 0 && longitude == 0);

  Vehicle copyWith({
    String? id,
    String? displayName,
    String? providerKey,
    String? imei,
    double? latitude,
    double? longitude,
    double? speedKmph,
    bool? ignition,
    String? lastUpdatedRaw,
    DateTime? lastUpdated,
    VehicleStatus? status,
    Map<String, dynamic>? rawJson,
  }) {
    return Vehicle(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      providerKey: providerKey ?? this.providerKey,
      imei: imei ?? this.imei,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speedKmph: speedKmph ?? this.speedKmph,
      ignition: ignition ?? this.ignition,
      lastUpdatedRaw: lastUpdatedRaw ?? this.lastUpdatedRaw,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      status: status ?? this.status,
      rawJson: rawJson ?? this.rawJson,
    );
  }
}
