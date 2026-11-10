/// Credentials for one provider account, mirroring the CampusMan
/// `transport` table columns.
///
/// - [deviceId] is `gps_device_id` (IMEI, vehicle id, or username).
/// - [secret] is `gps_password` (API key, `userId:key`, or account
///   password). Secrets are never logged and are stored only in
///   flutter_secure_storage — never in plain text or in this object
///   beyond a single request.
/// - [regNo] is `vehicle_no`, used for display and fallback matching.
class ProviderCredentials {
  const ProviderCredentials({
    required this.deviceId,
    required this.secret,
    this.regNo,
    this.displayName,
  });

  final String deviceId;
  final String secret;
  final String? regNo;
  final String? displayName;
}
