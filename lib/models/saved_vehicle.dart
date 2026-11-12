import 'vehicle_category.dart';

/// A vehicle the user added in UniTrack.
///
/// Only non-secret fields live here — this is what gets stored in
/// shared_preferences. The secret (API key / password) lives separately
/// in flutter_secure_storage under `unitrack_secret_<id>` and is never
/// part of this object.
class SavedVehicle {
  const SavedVehicle({
    required this.id,
    required this.providerKey,
    required this.deviceId,
    this.regNo,
    this.displayName,
    this.category = VehicleCategory.other,
  });

  /// Local id, unique per saved vehicle.
  final String id;

  /// Lowercase provider key, e.g. 'aargee' (see [GpsProvider]).
  final String providerKey;

  /// `gps_device_id`: IMEI, numeric vehicle id, or account username.
  final String deviceId;

  /// `vehicle_no`: registration number, for display / fallback matching.
  final String? regNo;

  /// Optional friendly name shown in the fleet list.
  final String? displayName;

  /// The kind of vehicle (bus / car / truck / bike / other), picked
  /// in the add-vehicle wizard. Defaults to [VehicleCategory.other]
  /// for saves from before categories existed.
  final VehicleCategory category;

  Map<String, dynamic> toJson() => {
    'id': id,
    'providerKey': providerKey,
    'deviceId': deviceId,
    if (regNo != null) 'regNo': regNo,
    if (displayName != null) 'displayName': displayName,
    'category': category.name,
  };

  factory SavedVehicle.fromJson(Map<String, dynamic> json) {
    return SavedVehicle(
      id: json['id'] as String,
      providerKey: json['providerKey'] as String,
      deviceId: json['deviceId'] as String,
      regNo: json['regNo'] as String?,
      displayName: json['displayName'] as String?,
      category: VehicleCategory.fromKey(json['category'] as String?),
    );
  }
}
