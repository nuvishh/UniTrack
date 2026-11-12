/// How a provider authenticates.
enum AuthType {
  /// A single API key (Transight, Aargee, HashTrace).
  apiKey,

  /// A user id plus a key, usually combined as `userId:key` in one field
  /// (LiveTrace, SimplyTrack).
  userIdAndKey,

  /// An account username plus an account password
  /// (MercyDataTrack, PauldeaTrack).
  usernamePassword,
}

/// The GPS providers UniTrack supports, mirroring the CampusMan GPS
/// integration guide (GPS_INTEGRATION_GUIDE.md).
///
/// [verified] marks the providers whose API contract was tested live
/// against the real API (2026-11-09 for LiveTrace, SimplyTrack,
/// HashTrace and Aargee; 2026-11-11 for MercyDataTrack, PauldeaTrack
/// and Transight; 2026-11-12 for MercyDataTrack 4G). All 8 providers
/// are now live-verified.
enum GpsProvider {
  transight(
    key: 'transight',
    displayName: 'Transight GPS',
    authType: AuthType.apiKey,
    deviceIdLabel: 'IMEI / Vehicle ID',
    deviceIdHint: '15-digit IMEI, or numeric vehicle ID',
    secretLabel: 'API Key',
    secretHint: '36-character Transight API key',
    supportsHistory: true,
    verified: true,
    minPollInterval: Duration(seconds: 60),
    rateLimitNote:
        'Last-data 500/day; vehicle list 100/day; history 10/day/vehicle.',
  ),
  aargee(
    key: 'aargee',
    displayName: 'Aargee GPS',
    authType: AuthType.apiKey,
    deviceIdLabel: 'IMEI / Vehicle ID',
    deviceIdHint: '15-digit IMEI, or numeric vehicle ID',
    secretLabel: 'API Key',
    secretHint: 'Aargee Compass API key',
    supportsHistory: true,
    verified: true,
    minPollInterval: Duration(seconds: 60),
    rateLimitNote:
        'Last-data 500/day; vehicle list 100/day; history 10/day/vehicle.',
  ),
  radiant(
    key: 'radiant',
    displayName: 'Radiant / LiveTrace',
    authType: AuthType.userIdAndKey,
    deviceIdLabel: 'IMEI / User ID',
    deviceIdHint: 'Device IMEI, or account user ID',
    secretLabel: 'User ID : Key',
    secretHint: 'userid:key, or just the key if user ID is above',
    supportsHistory: false,
    verified: true,
    minPollInterval: Duration(seconds: 30),
    rateLimitNote: 'No rate limit documented.',
  ),
  mercydatrack(
    key: 'mercydatrack',
    displayName: 'MercyDataTrack',
    authType: AuthType.usernamePassword,
    deviceIdLabel: 'Vehicle Registration',
    deviceIdHint: 'Registration number, e.g. KL00XX0000',
    secretLabel: 'Username : Password',
    secretHint: 'username:password',
    supportsHistory: false,
    verified: true,
    minPollInterval: Duration(seconds: 60),
    rateLimitNote: 'Rate limit not documented in the guide.',
  ),
  mercydatrack4g(
    key: 'mercydatrack4g',
    displayName: 'MercyDataTrack (4G)',
    authType: AuthType.usernamePassword,
    deviceIdLabel: 'Vehicle Registration',
    deviceIdHint: 'Registration number, or chassis number (4G devices)',
    secretLabel: 'Username : Password',
    secretHint: 'username:password',
    supportsHistory: false,
    verified: true,
    minPollInterval: Duration(seconds: 60),
    rateLimitNote: 'Rate limit not documented in the guide.',
  ),
  pauldeatrack(
    key: 'pauldeatrack',
    displayName: 'PauldeaTrack',
    authType: AuthType.usernamePassword,
    deviceIdLabel: 'Vehicle Registration',
    deviceIdHint: 'Registration number, e.g. KL00XX0000',
    secretLabel: 'Username : Password',
    secretHint: 'username:password',
    supportsHistory: false,
    verified: true,
    minPollInterval: Duration(seconds: 60),
    rateLimitNote: 'Rate limit not documented in the guide.',
  ),
  voltysoft(
    key: 'voltysoft',
    displayName: 'Voltysoft / SimplyTrack',
    authType: AuthType.userIdAndKey,
    deviceIdLabel: 'IMEI / User ID',
    deviceIdHint: '15-digit IMEI, or userId:imei',
    secretLabel: 'User ID : API Key',
    secretHint: 'userId:apiKey, or just the API key',
    supportsHistory: true,
    verified: true,
    minPollInterval: Duration(seconds: 60),
    rateLimitNote: 'Strict 100 requests/hour — poll slowly.',
  ),
  hashtrace(
    key: 'hashtrace',
    displayName: 'HashTrace Tracker',
    authType: AuthType.apiKey,
    deviceIdLabel: 'Vehicle ID / IMEI',
    deviceIdHint: 'Numeric VId, or 15-digit IMEI',
    secretLabel: 'Auth Key',
    secretHint: 'HashTrace account authKey',
    supportsHistory: false,
    verified: true,
    minPollInterval: Duration(seconds: 30),
    rateLimitNote: 'No rate limit documented — poll every 30–60s.',
  );

  const GpsProvider({
    required this.key,
    required this.displayName,
    required this.authType,
    required this.deviceIdLabel,
    required this.deviceIdHint,
    required this.secretLabel,
    required this.secretHint,
    required this.supportsHistory,
    required this.verified,
    required this.minPollInterval,
    required this.rateLimitNote,
  });

  /// Lowercase key used in the CampusMan `transport.gps_provider` column.
  final String key;

  final String displayName;
  final AuthType authType;

  /// Labels for the add-vehicle form, taken from the GPS guide.
  final String deviceIdLabel;
  final String deviceIdHint;
  final String secretLabel;
  final String secretHint;

  /// False for providers that only return live snapshots (HashTrace,
  /// LiveTrace) — the detail screen shows "history not supported" for
  /// these instead of a history button.
  final bool supportsHistory;

  /// True when the API contract was verified live on 2026-11-09.
  final bool verified;

  /// Shortest allowed gap between two polls for one account of this
  /// provider. The tracker never polls faster than this, however short
  /// the user sets the global refresh interval.
  final Duration minPollInterval;

  final String rateLimitNote;

  /// Looks a provider up by its lowercase key. Throws [ArgumentError]
  /// for unknown keys.
  static GpsProvider fromKey(String key) {
    for (final provider in GpsProvider.values) {
      if (provider.key == key) return provider;
    }
    throw ArgumentError('Unknown GPS provider key: $key');
  }
}
