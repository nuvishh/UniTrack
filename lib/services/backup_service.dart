import 'dart:convert';

import '../models/vehicle_category.dart';

/// Backup & restore for the vehicle configuration.
///
/// Export writes one JSON file with every saved vehicle — provider key,
/// device id, display name and its credentials (API key /
/// username:password as stored). Import reads such a file back.
///
/// SECURITY: the file contains secrets in plain text. The export
/// screen MUST warn the user to keep the file private and never share
/// it. Credential values are never logged and never included in any
/// error message. No passphrase encryption is built in (see the
/// Settings warning) — the file is only as safe as where the user
/// keeps it.
class BackupFormatException implements Exception {
  BackupFormatException(this.message);

  /// Human-readable reason, safe to show in the UI (never contains
  /// file content or credential values).
  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// One vehicle inside a backup file.
class BackupVehicle {
  const BackupVehicle({
    required this.providerKey,
    required this.deviceId,
    required this.secret,
    this.regNo,
    this.displayName,
    this.category = VehicleCategory.other,
  });

  final String providerKey;
  final String deviceId;

  /// API key / username:password, exactly as stored.
  final String secret;
  final String? regNo;
  final String? displayName;

  /// Vehicle category. Optional in the file: backups exported before
  /// categories existed have no such field and import as [other].
  final VehicleCategory category;

  Map<String, dynamic> toJson() => {
    'providerKey': providerKey,
    'deviceId': deviceId,
    'secret': secret,
    if (regNo != null) 'regNo': regNo,
    if (displayName != null) 'displayName': displayName,
    'category': category.name,
  };

  /// Strict parse: missing or wrongly-typed required fields fail.
  factory BackupVehicle.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw BackupFormatException('A vehicle entry is not an object.');
    }
    final providerKey = json['providerKey'];
    final deviceId = json['deviceId'];
    final secret = json['secret'];
    if (providerKey is! String || providerKey.trim().isEmpty) {
      throw BackupFormatException(
        'A vehicle entry has no providerKey.',
      );
    }
    if (deviceId is! String || deviceId.trim().isEmpty) {
      throw BackupFormatException(
        'A vehicle entry has no deviceId.',
      );
    }
    if (secret is! String || secret.isEmpty) {
      throw BackupFormatException(
        'A vehicle entry for "$providerKey" has no credentials.',
      );
    }
    final regNo = json['regNo'];
    final displayName = json['displayName'];
    if (regNo != null && regNo is! String) {
      throw BackupFormatException('A vehicle entry has a bad regNo.');
    }
    if (displayName != null && displayName is! String) {
      throw BackupFormatException(
        'A vehicle entry has a bad displayName.',
      );
    }
    final category = json['category'];
    if (category != null && category is! String) {
      throw BackupFormatException('A vehicle entry has a bad category.');
    }
    return BackupVehicle(
      providerKey: providerKey.trim(),
      deviceId: deviceId.trim(),
      secret: secret,
      regNo: regNo as String?,
      displayName: displayName as String?,
      category: VehicleCategory.fromKey(category as String?),
    );
  }
}

/// Current backup schema version. Bump when the format changes, and
/// keep [parseBackup] accepting older versions it understands.
const int backupSchemaVersion = 1;

/// Builds the backup JSON for [vehicles]. Pure function — no I/O.
String buildBackupJson(List<BackupVehicle> vehicles) {
  return const JsonEncoder.withIndent('  ').convert({
    'app': 'UniTrack',
    'schemaVersion': backupSchemaVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'vehicles': vehicles.map((v) => v.toJson()).toList(),
  });
}

/// Parses backup JSON strictly. Throws [BackupFormatException] with a
/// readable reason on bad JSON, wrong shape, unsupported schema
/// version, or missing fields — never a crash, never file content in
/// the message.
List<BackupVehicle> parseBackup(String source) {
  dynamic decoded;
  try {
    decoded = jsonDecode(source);
  } catch (_) {
    throw BackupFormatException(
      'This file is not valid JSON. Pick a UniTrack backup (.json) file.',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw BackupFormatException(
      'This is not a UniTrack backup — the file must start with an object.',
    );
  }
  final schemaVersion = decoded['schemaVersion'];
  if (schemaVersion is! int) {
    throw BackupFormatException(
      'This file has no schema version — it is not a UniTrack backup.',
    );
  }
  if (schemaVersion != backupSchemaVersion) {
    throw BackupFormatException(
      'This backup uses schema v$schemaVersion, but this app reads '
      'v$backupSchemaVersion. Update the app, or export a fresh backup.',
    );
  }
  final rawVehicles = decoded['vehicles'];
  if (rawVehicles is! List) {
    throw BackupFormatException(
      'This backup has no vehicle list.',
    );
  }
  return rawVehicles.map(BackupVehicle.fromJson).toList();
}

/// Splits imported vehicles into new ones and duplicates.
/// A duplicate is a vehicle with the same provider key and device id
/// (case-insensitive, trimmed) as one already saved.
({List<BackupVehicle> fresh, int skipped}) planImport(
  List<BackupVehicle> existing,
  List<BackupVehicle> imported,
) {
  final known = existing
      .map(
        (v) => '${v.providerKey}::${v.deviceId.trim().toUpperCase()}',
      )
      .toSet();
  final fresh = <BackupVehicle>[];
  var skipped = 0;
  for (final vehicle in imported) {
    final key =
        '${vehicle.providerKey}::${vehicle.deviceId.trim().toUpperCase()}';
    if (known.contains(key)) {
      skipped++;
    } else {
      known.add(key);
      fresh.add(vehicle);
    }
  }
  return (fresh: fresh, skipped: skipped);
}
