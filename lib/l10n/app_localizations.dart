import 'dart:async';

import 'package:flutter/material.dart';

import '../models/vehicle.dart';
import '../models/vehicle_category.dart';

/// Hand-rolled localisations (no codegen): English + Malayalam.
///
/// Every user-facing string in the app lives in [_strings] under a
/// stable key; screens read them through typed getters on
/// [AppLocalizations.of(context)]. A missing key falls back to the
/// English value, and [AppLocalizations.of] falls back to English
/// when no delegate is in the tree (widget tests that pump screens
/// bare, without the app's [MaterialApp]).
///
/// Provider names, reg numbers, IMEIs and error text from providers
/// are data, not UI strings — they are never translated.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  /// 'en' unless the locale is Malayalam — any other locale (e.g.
  /// the device default en_US) reads English.
  String get languageCode => locale.languageCode == 'ml' ? 'ml' : 'en';

  String t(String key) =>
      _strings[languageCode]?[key] ?? _strings['en']![key] ?? key;

  String tp(String key, [Map<String, String> params = const {}]) {
    var value = t(key);
    for (final entry in params.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value);
    }
    return value;
  }

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      AppLocalizations(const Locale('en'));

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [Locale('en'), Locale('ml')];

  /// Every key, for tests: each one must exist in both locales.
  static Set<String> get allKeys => _strings['en']!.keys.toSet();

  static String? valueFor(String languageCode, String key) =>
      _strings[languageCode]?[key];

  // ---- Common words ----
  String get ok => t('ok');
  String get cancel => t('cancel');
  String get save => t('save');
  String get done => t('done');
  String get close => t('close');
  String get retry => t('retry');
  String get back => t('back');
  String get continueLabel => t('continue');
  String get clearAll => t('clearAll');
  String get loading => t('loading');
  String get testConnection => t('testConnection');
  String get testing => t('testing');
  String get share => t('share');
  String get remove => t('remove');
  String get edit => t('edit');

  // ---- App + bottom nav ----
  String get appTitle => t('appTitle');
  String get appSubtitle => t('appSubtitle');
  String get navFleet => t('navFleet');
  String get navMap => t('navMap');
  String get navAdd => t('navAdd');
  String get navSettings => t('navSettings');

  // ---- Fleet ----
  String get searchHint => t('searchHint');
  String get filterAll => t('filterAll');
  String get filterLive => t('filterLive');
  String get filterIdle => t('filterIdle');
  String get filterOffline => t('filterOffline');
  String get filters => t('filters');
  String get provider => t('provider');
  String get category => t('category');
  String get emptyFleetTitle => t('emptyFleetTitle');
  String get emptyFleetMessage => t('emptyFleetMessage');
  String get emptyFleetAction => t('emptyFleetAction');
  String get noMatchesTitle => t('noMatchesTitle');
  String get noMatchesMessage => t('noMatchesMessage');
  String get noMatchesAction => t('noMatchesAction');
  String get refreshErrorTitle => t('refreshErrorTitle');
  String get refreshNow => t('refreshNow');
  String get themeToggleLight => t('themeToggleLight');
  String get themeToggleDark => t('themeToggleDark');
  String get updating => t('updating');
  String get notUpdatedYet => t('notUpdatedYet');
  String get lastUpdateUnknown => t('lastUpdateUnknown');
  String get navigate => t('navigate');
  String get mapAction => t('mapAction');
  String get live => t('live');
  String get idle => t('idle');
  String get unknown => t('unknown');
  String get expired => t('expired');
  String get speed => t('speed');
  String get ignition => t('ignition');
  String get ignitionOn => t('ignitionOn');
  String get ignitionOff => t('ignitionOff');
  String get lastSeen => t('lastSeen');
  String get justNow => t('justNow');
  String get today => t('today');
  String get yesterday => t('yesterday');
  String get allDay => t('allDay');
  String get clearSearch => t('clearSearch');
  String get speedUnknown => t('speedUnknown');
  String get shareUnavailableCopied => t('shareUnavailableCopied');
  String get multiApiTelemetry => t('multiApiTelemetry');

  String noMatchesDetail(String query) => tp('noMatchesDetail', {'q': query});

  /// "3 vehicles · 2 providers" subtitle under the app title.
  String fleetSubtitle(int vehicleCount, int providerCount) {
    final vehicles = vehicleCount == 1
        ? tp('vehiclesOne', {'n': '$vehicleCount'})
        : tp('vehiclesMany', {'n': '$vehicleCount'});
    final providers = providerCount == 1
        ? tp('providersOne', {'n': '$providerCount'})
        : tp('providersMany', {'n': '$providerCount'});
    return '$vehicles · $providers';
  }

  /// "Live (3)" style chip label — the same shape in both languages.
  String countChip(String label, int count) => '$label ($count)';

  String minutesAgo(int n) => tp('minutesAgo', {'n': '$n'});
  String hoursAgo(int n) => tp(n == 1 ? 'hourAgo' : 'hoursAgo', {'n': '$n'});
  String daysAgo(int n) => tp(n == 1 ? 'dayAgo' : 'daysAgo', {'n': '$n'});

  /// Relative time: "just now", "2 min ago", "3 h ago" — localised.
  String relativeTime(DateTime? when, {DateTime? now}) {
    if (when == null) return unknown;
    final diff = (now ?? DateTime.now()).difference(when);
    if (diff.isNegative || diff.inSeconds < 45) return justNow;
    if (diff.inMinutes < 60) return minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return hoursAgo(diff.inHours);
    return daysAgo(diff.inDays);
  }

  /// "Updated 2 min ago" / "Last update unknown" — localised.
  String lastUpdatedLabel(Vehicle vehicle) {
    if (vehicle.lastUpdated != null) {
      return tp('updatedPrefix', {'time': relativeTime(vehicle.lastUpdated)});
    }
    if (vehicle.lastUpdatedRaw.isEmpty) return lastUpdateUnknown;
    return tp('updatedPrefix', {'time': vehicle.lastUpdatedRaw});
  }

  /// Speed text, or '—' when the provider did not report one.
  String speedLabel(Vehicle vehicle) {
    final speed = vehicle.speedKmph;
    if (speed == null) return '—';
    return tp('speedKmh', {'n': speed.toStringAsFixed(0)});
  }

  /// Localised status word for a [VehicleStatus].
  String statusLabel(VehicleStatus status) => switch (status) {
    VehicleStatus.live => live,
    VehicleStatus.idle => idle,
    VehicleStatus.unknown => unknown,
    VehicleStatus.expired => expired,
  };

  /// Localised category word.
  String categoryLabel(VehicleCategory category) => switch (category) {
    VehicleCategory.bus => t('categoryBus'),
    VehicleCategory.car => t('categoryCar'),
    VehicleCategory.truck => t('categoryTruck'),
    VehicleCategory.bike => t('categoryBike'),
    VehicleCategory.other => t('categoryOther'),
  };

  // ---- Map ----
  String get mapEmptyTitle => t('mapEmptyTitle');
  String get mapEmptyMessage => t('mapEmptyMessage');
  String get noLocation => t('noLocation');
  String get liveVehicles => t('liveVehicles');
  String get allVehicles => t('allVehicles');

  // ---- Add vehicle ----
  String get addVehicleTitle => t('addVehicleTitle');
  String get addVehicleSubtitle => t('addVehicleSubtitle');
  String get stepProvider => t('stepProvider');
  String get stepCredentials => t('stepCredentials');
  String get stepDetails => t('stepDetails');
  String get step1Title => t('step1Title');
  String get step1Hint => t('step1Hint');
  String get step2Hint => t('step2Hint');
  String get step3Title => t('step3Title');
  String get step3Hint => t('step3Hint');
  String get displayNameLabel => t('displayNameLabel');
  String get displayNameHint => t('displayNameHint');
  String get categoryField => t('categoryField');
  String get enterNameError => t('enterNameError');
  String get testBeforeSave => t('testBeforeSave');
  String get saveVehicle => t('saveVehicle');
  String get addAnother => t('addAnother');
  String get vehicleSaved => t('vehicleSaved');
  String get connectionOk => t('connectionOk');
  String get connectionFailed => t('connectionFailed');
  String get vehicleNotFound => t('vehicleNotFound');

  String enterCredentialsTitle(String providerName) =>
      tp('step2Title', {'provider': providerName});
  String enterSecretError(String label) =>
      tp('enterSecretError', {'label': label});

  // ---- Vehicle detail ----
  String get detailTitle => t('detailTitle');
  String get status => t('status');
  String get vehicleId => t('vehicleId');
  String get providerLabel => t('providerLabel');
  String get lastUpdated => t('lastUpdated');
  String get coordinates => t('coordinates');
  String get todaysTrip => t('todaysTrip');
  String get todaysRoute => t('todaysRoute');
  String get history => t('history');
  String get distance => t('distance');
  String get drivingTime => t('drivingTime');
  String get stops => t('stops');
  String get start => t('start');
  String get end => t('end');
  String get topSpeed => t('topSpeed');
  String get noTripsToday => t('noTripsToday');
  String get noTripsMessage => t('noTripsMessage');
  String get noHistory => t('noHistory');
  String get historyUnavailable => t('historyUnavailable');
  String get historyError => t('historyError');
  String get removeVehicle => t('removeVehicle');
  String get vehicleRemoved => t('vehicleRemoved');
  String get shareVehicle => t('shareVehicle');
  String get openInMaps => t('openInMaps');
  String get copied => t('copied');

  String removeVehicleConfirm(String name) =>
      tp('removeVehicleConfirm', {'name': name});

  // ---- Settings ----
  String get settingsTitle => t('settingsTitle');
  String get appearance => t('appearance');
  String get themeMode => t('themeMode');
  String get themeSystem => t('themeSystem');
  String get themeLight => t('themeLight');
  String get themeDark => t('themeDark');
  String get colourTheme => t('colourTheme');
  String get colourThemeSubtitle => t('colourThemeSubtitle');
  String get language => t('language');
  String get languageSystem => t('languageSystem');
  String get languageEnglish => t('languageEnglish');
  String get languageMalayalam => t('languageMalayalam');
  String get notifications => t('notifications');
  String get vehicleAlerts => t('vehicleAlerts');
  String get vehicleAlertsSubtitle => t('vehicleAlertsSubtitle');
  String get ignitionChanges => t('ignitionChanges');
  String get ignitionChangesSubtitle => t('ignitionChangesSubtitle');
  String get overspeed => t('overspeed');
  String get overspeedSubtitle => t('overspeedSubtitle');
  String get offlineAlerts => t('offlineAlerts');
  String get offlineAlertsSubtitle => t('offlineAlertsSubtitle');
  String get shareApp => t('shareApp');
  String get shareAppSubtitle => t('shareAppSubtitle');
  String get data => t('data');
  String get backupRestore => t('backupRestore');
  String get exportBackup => t('exportBackup');
  String get exportBackupSubtitle => t('exportBackupSubtitle');
  String get importBackup => t('importBackup');
  String get importBackupSubtitle => t('importBackupSubtitle');
  String get refreshInterval => t('refreshInterval');
  String get refreshIntervalSubtitle => t('refreshIntervalSubtitle');
  String get savedVehicles => t('savedVehicles');
  String get providers => t('providers');
  String get providerVerified => t('providerVerified');
  String get providerSetupNeeded => t('providerSetupNeeded');
  String get about => t('about');
  String get aboutUniTrack => t('aboutUniTrack');
  String get exportFailed => t('exportFailed');
  String get importFailed => t('importFailed');
  String get backupImported => t('backupImported');
  String get backupExported => t('backupExported');
  String get noSavedVehicles => t('noSavedVehicles');

  String versionLabel(String version) => tp('versionLabel', {'v': version});
  String intervalSeconds(int n) => tp('intervalSeconds', {'n': '$n'});
  String intervalMinutes(int n) => tp('intervalMinutes', {'n': '$n'});

  /// "30 sec" / "1 min" / "2 min" / "5 min" interval option label.
  String intervalLabel(Duration interval) {
    if (interval.inMinutes >= 1) return intervalMinutes(interval.inMinutes);
    return intervalSeconds(interval.inSeconds);
  }

  // ---- Add vehicle (steps 2–3, test results) ----
  String get previousStep => t('previousStep');
  String get testAndSave => t('testAndSave');
  String get testAgain => t('testAgain');
  String get saving => t('saving');
  String get testFirstNote => t('testFirstNote');
  String get step1Hint2 => t('step1Hint2');
  String get authApiKey => t('authApiKey');
  String get authUserIdAndKey => t('authUserIdAndKey');
  String get authUsernamePassword => t('authUsernamePassword');
  String get authDefault => t('authDefault');
  String get livePlusHistory => t('livePlusHistory');
  String get liveOnly => t('liveOnly');
  String get remoteBadge => t('remoteBadge');
  String get step2Subtitle => t('step2Subtitle');
  String get deviceIdHelper => t('deviceIdHelper');
  String get secretHelper => t('secretHelper');
  String get required => t('required');
  String get hide => t('hide');
  String get show => t('show');
  String get regNoLabel => t('regNoLabel');
  String get regNoHint => t('regNoHint');
  String get displayNameOptionalLabel => t('displayNameOptionalLabel');
  String get displayNameOptionalHint => t('displayNameOptionalHint');
  String get vehicleType => t('vehicleType');
  String get vehicleTypeHint => t('vehicleTypeHint');
  String get testStepTitle => t('testStepTitle');
  String get testIdleHint => t('testIdleHint');
  String get contactingProvider => t('contactingProvider');
  String get connectedTitle => t('connectedTitle');
  String get unknownError => t('unknownError');
  String get whatToCheck => t('whatToCheck');
  String get checkApiKey => t('checkApiKey');
  String get checkDeviceId => t('checkDeviceId');
  String get checkRegistered => t('checkRegistered');
  String get credentialsPrivacy => t('credentialsPrivacy');
  String get noVehiclesError => t('noVehiclesError');
  String get notSupportedYet => t('notSupportedYet');
  String get timeoutError => t('timeoutError');
  String get unexpectedResponseError => t('unexpectedResponseError');

  String notVerifiedWarning(String providerName) =>
      tp('notVerifiedWarning', {'provider': providerName});
  String testStepHint(String providerName) =>
      tp('testStepHint', {'provider': providerName});
  String vehiclesFound(int n, String providerName) => tp(
    n == 1 ? 'vehiclesFoundOne' : 'vehiclesFoundMany',
    {'n': '$n', 'provider': providerName},
  );
  String unreachableError(String providerName) =>
      tp('unreachableError', {'provider': providerName});
  String connectionFailedDetail(String error) =>
      tp('connectionFailedDetail', {'error': error});

  // ---- Vehicle detail (extra) ----
  String get backToFleet => t('backToFleet');
  String get liveLocationHint => t('liveLocationHint');
  String get coordinatesCopied => t('coordinatesCopied');
  String get ignitionOnRunning => t('ignitionOnRunning');
  String get ignitionOffParked => t('ignitionOffParked');
  String get vehicleSection => t('vehicleSection');
  String get typeLabel => t('typeLabel');
  String get regNoLabel2 => t('regNoLabel2');
  String get locationLabel => t('locationLabel');
  String get noFixYet => t('noFixYet');
  String get copyCoordinates => t('copyCoordinates');
  String get loadTodaysRoute => t('loadTodaysRoute');
  String get noTripData => t('noTripData');
  String get idling => t('idling');
  String get stopped => t('stopped');
  String get exportCsv => t('exportCsv');
  String get reportShared => t('reportShared');

  String historyLoadError(String error) =>
      tp('historyLoadError', {'error': error});
  String providerTime(String time) => tp('providerTime', {'time': time});
  String historyNotSupported(String providerName) =>
      tp('historyNotSupported', {'provider': providerName});
  String pointsToday(int n) =>
      tp(n == 1 ? 'pointsTodayOne' : 'pointsTodayMany', {'n': '$n'});
  String pointsTodayLog(int n) =>
      tp(n == 1 ? 'pointsTodayLogOne' : 'pointsTodayLogMany', {'n': '$n'});

  // ---- Map (extra) ----
  String get viewDetails => t('viewDetails');
  String get ignitionUnknown => t('ignitionUnknown');
  String get ignitionOnText => t('ignitionOnText');
  String get ignitionOffText => t('ignitionOffText');
  String get noVehiclesWithLocation => t('noVehiclesWithLocation');
  String get fitAllVehicles => t('fitAllVehicles');
  String get centreOnLive => t('centreOnLive');
  String get mapEmptyTitle2 => t('mapEmptyTitle2');
  String get mapEmptyMessage2 => t('mapEmptyMessage2');
  String get noLocationsYet => t('noLocationsYet');

  // ---- Map type + Google Maps (v1.5.0) ----
  String get mapTypeOsm => t('mapTypeOsm');
  String get mapTypeGoogle => t('mapTypeGoogle');
  String get loadingGoogleMap => t('loadingGoogleMap');
  String get shareLiveLocation => t('shareLiveLocation');
  String get shareLiveLocationShort => t('shareLiveLocationShort');

  String shareLiveLocationText(String name, String url) =>
      tp('shareLiveLocationText', {'name': name, 'url': url});

  // ---- Trip playback (v1.5.0) ----
  String get playTrip => t('playTrip');
  String get pauseTrip => t('pauseTrip');
  String get tripPlayback => t('tripPlayback');
  String get tripPlaybackNotAvailable => t('tripPlaybackNotAvailable');

  String playbackPoint(int index, int total) =>
      tp('playbackPoint', {'index': '$index', 'total': '$total'});

  String mapCountLabel(int liveCount, int idleCount, int total) => tp(
    'mapCountLabel',
    {'live': '$liveCount', 'idle': '$idleCount', 'total': '$total'},
  );

  // ---- Settings (extra) ----
  String get settingsSubtitle => t('settingsSubtitle');
  String get themeAppliesNote => t('themeAppliesNote');
  String get backupCardText => t('backupCardText');
  String get exportConfig => t('exportConfig');
  String get importConfig => t('importConfig');
  String get backupWarning => t('backupWarning');
  String get removeVehicleTitle => t('removeVehicleTitle');
  String get nothingToBackup => t('nothingToBackup');
  String get exportKeysTitle => t('exportKeysTitle');
  String get exportAnyway => t('exportAnyway');
  String get couldNotReadFile => t('couldNotReadFile');

  // ---- Google Maps key (v1.5.0) ----
  String get mapSettings => t('mapSettings');
  String get googleMapsApiKey => t('googleMapsApiKey');
  String get googleMapsApiKeyHint => t('googleMapsApiKeyHint');
  String get googleMapsApiKeyHelp => t('googleMapsApiKeyHelp');
  String get googleMapsKeySaved => t('googleMapsKeySaved');
  String get googleMapsKeyRemoved => t('googleMapsKeyRemoved');
  String get googleMapsKeyApplyFailed => t('googleMapsKeyApplyFailed');
  String get googleMapsRestartNote => t('googleMapsRestartNote');
  String get saveKey => t('saveKey');
  String get clearKey => t('clearKey');
  String get couldNotReadBackup => t('couldNotReadBackup');
  String get backupNoVehicles => t('backupNoVehicles');
  String get noVehiclesSavedMessage => t('noVehiclesSavedMessage');
  String get refreshProviders => t('refreshProviders');
  String get providerListUpdated => t('providerListUpdated');
  String get providerListOffline => t('providerListOffline');
  String get providerListBuiltin => t('providerListBuiltin');
  String get aboutText => t('aboutText');
  String get aboutPrivacy => t('aboutPrivacy');

  String removeVehicleContent(String name) =>
      tp('removeVehicleContent', {'name': name});
  String exportKeysContent(int n) => tp(
    n == 1 ? 'exportKeysContentOne' : 'exportKeysContentMany',
    {'n': '$n'},
  );
  String backupNothingNew(int n) =>
      tp(n == 1 ? 'backupNothingNewOne' : 'backupNothingNewMany', {'n': '$n'});
  String importResultMessage(int imported, int skipped) {
    final base = tp('importedCount', {'n': '$imported'});
    if (skipped == 0) return '$base.';
    return '$base, ${tp(skipped == 1 ? 'skippedDuplicateOne' : 'skippedDuplicateMany', {'n': '$skipped'})}.';
  }

  String refreshIntervalNote(String interval) =>
      tp('refreshIntervalNote', {'interval': interval});
  String everySeconds(int n) => tp('everySeconds', {'n': '$n'});
  String everyMinutes(int n) =>
      tp(n == 1 ? 'everyMinute' : 'everyMinutes', {'n': '$n'});
  String couldNotLoadSaved(String error) =>
      tp('couldNotLoadSaved', {'error': error});
  String providerListRemote(int version) =>
      tp('providerListRemote', {'v': '$version'});
  String providerListCached(int version) =>
      tp('providerListCached', {'v': '$version'});

  // ---- Notification text (used by the alert service, no context) ----
  String get alertChannelName => t('alertChannelName');
  String alertIgnitionOnTitle(String name) =>
      tp('alertIgnitionOnTitle', {'name': name});
  String alertIgnitionOnBody(double? speed) => speed == null
      ? t('alertIgnitionOnBodyNoSpeed')
      : tp('alertIgnitionOnBody', {'speed': speed.toStringAsFixed(0)});
  String alertIgnitionOffTitle(String name) =>
      tp('alertIgnitionOffTitle', {'name': name});
  String alertIgnitionOffBody() => t('alertIgnitionOffBody');
  String alertOfflineTitle(String name) =>
      tp('alertOfflineTitle', {'name': name});
  String alertOfflineBody() => t('alertOfflineBody');
  String alertOverspeedTitle(String name) =>
      tp('alertOverspeedTitle', {'name': name});
  String alertOverspeedBody(double speed) =>
      tp('alertOverspeedBody', {'speed': speed.toStringAsFixed(0)});
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ml'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      Future<AppLocalizations>.value(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const Map<String, Map<String, String>> _strings = {
  'en': {
    'ok': 'OK',
    'cancel': 'Cancel',
    'save': 'Save',
    'done': 'Done',
    'close': 'Close',
    'retry': 'Retry',
    'back': 'Back',
    'continue': 'Continue',
    'clearAll': 'Clear all',
    'loading': 'Loading…',
    'testConnection': 'Test connection',
    'testing': 'Testing…',
    'share': 'Share',
    'remove': 'Remove',
    'edit': 'Edit',
    'appTitle': 'UniTrack',
    'appSubtitle': 'All your GPS providers, one fleet',
    'navFleet': 'Fleet',
    'navMap': 'Map',
    'navAdd': 'Add',
    'navSettings': 'Settings',
    'searchHint': 'Search by reg no, IMEI or provider',
    'filterAll': 'All',
    'filterLive': 'Live',
    'filterIdle': 'Idle',
    'filterOffline': 'Offline',
    'filters': 'Filters',
    'provider': 'Provider',
    'category': 'Category',
    'emptyFleetTitle': 'No vehicles yet',
    'emptyFleetMessage': 'Add a vehicle from any GPS provider — Transight, Aargee, LiveTrace, Mercydatrack, PauldeaTrack, SimplyTrack or HashTrace — and track them all here.',
    'emptyFleetAction': 'Add your first vehicle',
    'noMatchesTitle': 'No matches',
    'noMatchesDetail': 'Nothing in the fleet matches "{q}". Try a different reg no, provider or status.',
    'noMatchesMessage': 'Try a different search or clear the filters.',
    'noMatchesAction': 'Clear search & filters',
    'vehiclesOne': '{n} vehicle',
    'vehiclesMany': '{n} vehicles',
    'providersOne': '{n} provider',
    'providersMany': '{n} providers',
    'clearSearch': 'Clear search',
    'speedUnknown': 'speed unknown',
    'shareUnavailableCopied': 'Share unavailable — copied instead.',
    'multiApiTelemetry': 'Multi-API Telemetry',
    'refreshErrorTitle': "Couldn't refresh the fleet",
    'refreshNow': 'Refresh now',
    'themeToggleLight': 'Switch to light theme',
    'themeToggleDark': 'Switch to dark theme',
    'updating': 'Updating…',
    'notUpdatedYet': 'Not updated yet',
    'lastUpdateUnknown': 'Last update unknown',
    'navigate': 'Navigate',
    'mapAction': 'Map',
    'live': 'Live',
    'idle': 'Idle',
    'unknown': 'Unknown',
    'expired': 'Expired',
    'speed': 'Speed',
    'ignition': 'Ignition',
    'ignitionOn': 'On',
    'ignitionOff': 'Off',
    'lastSeen': 'Last seen',
    'justNow': 'just now',
    'minutesAgo': '{n} min ago',
    'hourAgo': '{n} hour ago',
    'hoursAgo': '{n} hours ago',
    'dayAgo': '{n} day ago',
    'daysAgo': '{n} days ago',
    'updatedPrefix': 'Updated {time}',
    'today': 'Today',
    'yesterday': 'Yesterday',
    'allDay': 'All day',
    'speedKmh': '{n} km/h',
    'categoryBus': 'Bus',
    'categoryCar': 'Car',
    'categoryTruck': 'Truck',
    'categoryBike': 'Bike',
    'categoryOther': 'Other',
    'mapEmptyTitle': 'No vehicles to show',
    'mapEmptyMessage': 'Add a vehicle to see it on the map.',
    'noLocation': 'No location yet',
    'liveVehicles': 'Live vehicles',
    'allVehicles': 'All vehicles',
    'addVehicleTitle': 'Add vehicle',
    'addVehicleSubtitle': 'Connect a GPS provider to start tracking a vehicle.',
    'stepProvider': 'Provider',
    'stepCredentials': 'Credentials',
    'stepDetails': 'Details',
    'step1Title': 'Which GPS provider is this vehicle on?',
    'step1Hint': 'Pick the provider your tracker reports to.',
    'step2Title': 'Enter {provider} credentials',
    'step2Hint': 'Your keys stay on this device only.',
    'step3Title': 'Name this vehicle',
    'step3Hint': 'Use the registration number — it shows in the fleet list.',
    'displayNameLabel': 'Display name',
    'displayNameHint': 'e.g. KL01AB1234',
    'categoryField': 'Category',
    'enterNameError': 'Enter a display name',
    'enterSecretError': 'Enter your {label}',
    'testBeforeSave': 'Test the connection before saving',
    'saveVehicle': 'Save vehicle',
    'addAnother': 'Add another',
    'vehicleSaved': 'Vehicle saved',
    'connectionOk': 'Connection looks good',
    'connectionFailed': 'Connection failed',
    'vehicleNotFound': 'Vehicle not found',
    'detailTitle': 'Vehicle details',
    'status': 'Status',
    'vehicleId': 'Vehicle ID',
    'providerLabel': 'Provider',
    'lastUpdated': 'Last updated',
    'coordinates': 'Coordinates',
    'todaysTrip': "Today's trip",
    'todaysRoute': "Today's route",
    'history': 'History',
    'distance': 'Distance',
    'drivingTime': 'Driving',
    'stops': 'Stops',
    'start': 'Start',
    'end': 'End',
    'topSpeed': 'Top speed',
    'noTripsToday': 'No trips today',
    'noTripsMessage': 'This vehicle has not moved today yet.',
    'noHistory': 'No history available',
    'historyUnavailable': 'History is not supported for this provider.',
    'historyError': 'Could not load history',
    'removeVehicle': 'Remove vehicle',
    'removeVehicleConfirm': 'Remove {name} from UniTrack?',
    'vehicleRemoved': 'Vehicle removed',
    'shareVehicle': 'Share vehicle',
    'openInMaps': 'Open in Maps',
    'copied': 'Copied',
    'settingsTitle': 'Settings',
    'appearance': 'Appearance',
    'themeMode': 'Theme',
    'themeSystem': 'System',
    'themeLight': 'Light',
    'themeDark': 'Dark',
    'colourTheme': 'Colour theme',
    'colourThemeSubtitle': 'Pick a seed colour — the whole app follows it',
    'language': 'Language',
    'languageSystem': 'System',
    'languageEnglish': 'English',
    'languageMalayalam': 'മലയാളം',
    'notifications': 'Notifications',
    'vehicleAlerts': 'Vehicle alerts',
    'vehicleAlertsSubtitle': 'Notify me about my vehicles',
    'ignitionChanges': 'Ignition changes',
    'ignitionChangesSubtitle': 'When a vehicle starts or stops',
    'overspeed': 'Overspeed (above 80 km/h)',
    'overspeedSubtitle': 'When a moving vehicle crosses 80 km/h',
    'offlineAlerts': 'Offline alerts',
    'offlineAlertsSubtitle': 'When a vehicle stops reporting',
    'shareApp': 'Share UniTrack',
    'shareAppSubtitle': 'Send the app link to someone',
    'data': 'Data',
    'backupRestore': 'Backup & restore',
    'exportBackup': 'Export backup',
    'exportBackupSubtitle': 'Save vehicles as a file you can import later',
    'importBackup': 'Import backup',
    'importBackupSubtitle': 'Restore vehicles from a backup file',
    'refreshInterval': 'Refresh interval',
    'refreshIntervalSubtitle': 'How often the fleet is polled',
    'savedVehicles': 'Saved vehicles',
    'providers': 'Providers',
    'providerVerified': 'Verified',
    'providerSetupNeeded': 'Setup needed',
    'about': 'About',
    'aboutUniTrack': 'UniTrack tracks every vehicle, across every GPS provider, in one place.',
    'versionLabel': 'Version {v}',
    'exportFailed': 'Export failed',
    'importFailed': 'Import failed',
    'backupImported': 'Backup imported',
    'backupExported': 'Backup exported',
    'noSavedVehicles': 'No vehicles saved yet',
    'intervalSeconds': '{n} sec',
    'intervalMinutes': '{n} min',
    'previousStep': 'Previous step',
    'testAndSave': 'Test & save',
    'testAgain': 'Test again',
    'saving': 'Saving…',
    'testFirstNote':
        'Test the connection first — Save unlocks after a successful test.',
    'step1Hint2': "Each provider has its own API. Pick the one the vehicle's tracker is registered with.",
    'authApiKey': 'Signs in with one API key',
    'authUserIdAndKey': 'Signs in with a user ID + key',
    'authUsernamePassword': 'Signs in with username + password',
    'authDefault': 'Signs in with its own credentials',
    'livePlusHistory': 'Live tracking + history',
    'liveOnly': 'Live tracking only (no history)',
    'remoteBadge': 'Remote',
    'step2Subtitle': 'These stay only on this device, in secure storage.',
    'notVerifiedWarning': '{provider} is not verified yet — its endpoint paths are not confirmed. Test connection will explain what is missing.',
    'deviceIdHelper': 'This identifies the vehicle at the provider.',
    'secretHelper': 'Never shared — stored only on this device.',
    'required': 'Required',
    'hide': 'Hide',
    'show': 'Show',
    'regNoLabel': 'Registration number (optional)',
    'regNoHint': 'Used for display and fallback matching',
    'displayNameOptionalLabel': 'Display name (optional)',
    'displayNameOptionalHint': 'Friendly name for the fleet list',
    'vehicleType': 'Vehicle type',
    'vehicleTypeHint': 'Shown as an icon on fleet cards and the map.',
    'testStepTitle': 'Test the connection',
    'testStepHint': "We'll contact {provider} with these credentials before saving anything.",
    'testIdleHint': 'Tap "Test connection" — if the provider answers with your vehicle, Save unlocks.',
    'contactingProvider': 'Contacting the provider…',
    'connectedTitle': 'Connected!',
    'vehiclesFoundOne': '{n} vehicle found on {provider}.',
    'vehiclesFoundMany': '{n} vehicles found on {provider}.',
    'unknownError': 'Unknown error.',
    'whatToCheck': 'What to check:',
    'checkApiKey': '• The API key / password is copied correctly',
    'checkDeviceId': '• The device ID matches the provider account',
    'checkRegistered': '• The vehicle is registered under this account',
    'credentialsPrivacy': "Credentials are stored only on this device, in secure storage. They are never uploaded anywhere except the provider's own API.",
    'noVehiclesError': 'Connected, but the account returned no vehicles. Check the device ID — it must match a vehicle registered under this account.',
    'notSupportedYet': 'Not supported yet.',
    'timeoutError': 'The provider took too long to answer. Check your internet connection and tap Test again.',
    'unreachableError': 'Could not reach {provider} — check your internet connection and try again.',
    'unexpectedResponseError': 'The provider returned an unexpected response. Try again, or check the API key.',
    'connectionFailedDetail': 'Connection failed: {error}',
    'backToFleet': 'Back to fleet',
    'liveLocationHint': 'Live location — tap for the full map',
    'coordinatesCopied': 'Coordinates copied.',
    'historyLoadError': 'Could not load history: {error}',
    'ignitionOnRunning': 'ON • Running',
    'ignitionOffParked': 'OFF • Parked',
    'vehicleSection': 'Vehicle',
    'typeLabel': 'Type',
    'regNoLabel2': 'Reg no',
    'locationLabel': 'Location',
    'noFixYet': 'No fix yet',
    'copyCoordinates': 'Copy coordinates',
    'providerTime': 'Provider time: {time}',
    'historyNotSupported': 'History is not supported by {provider} — it returns live snapshots only.',
    'loadTodaysRoute': "Load today's route",
    'pointsTodayOne': '{n} point today',
    'pointsTodayMany': '{n} points today',
    'pointsTodayLogOne': '{n} point today · Local trip log',
    'pointsTodayLogMany': '{n} points today · Local trip log',
    'noTripData': 'No trip data today yet — positions are recorded while the app polls. Check back after a drive.',
    'idling': 'Idling',
    'stopped': 'Stopped',
    'exportCsv': 'Export today as CSV',
    'reportShared': 'Report shared — save it from the share sheet.',
    'viewDetails': 'View details',
    'ignitionUnknown': 'Ignition unknown',
    'ignitionOnText': 'Ignition on',
    'ignitionOffText': 'Ignition off',
    'noVehiclesWithLocation': 'No vehicles with a location yet.',
    'mapCountLabel': '{live} live · {idle} idle · {total} total',
    'fitAllVehicles': 'Fit all vehicles',
    'centreOnLive': 'Centre on a live vehicle',
    'mapEmptyTitle2': 'No vehicles on the map yet',
    'mapEmptyMessage2': 'Add a vehicle and its live location will appear here.',
    'noLocationsYet': 'No locations to show yet — the providers have not returned a fix for these vehicles.',
    // v1.5.0: map type + Google Maps.
    'mapTypeOsm': 'OpenStreetMap',
    'mapTypeGoogle': 'Google Maps',
    'loadingGoogleMap': 'Loading Google Maps…',
    'shareLiveLocation': 'Share live location',
    'shareLiveLocationShort': 'Share',
    'shareLiveLocationText': '{name} — live location: {url}',
    // v1.5.0: trip playback.
    'playTrip': 'Play trip',
    'pauseTrip': 'Pause trip',
    'tripPlayback': 'Trip playback',
    'tripPlaybackNotAvailable':
        'Trip playback is not available for this provider — it does not share trip history.',
    'playbackPoint': 'Point {index} of {total}',
    'settingsSubtitle': 'Material You theme, polling intervals & providers',
    'themeAppliesNote': 'Applies immediately, in both light and dark mode.',
    'backupCardText': 'Reinstalling the app wipes saved vehicles and credentials. Export a backup first, then import it after reinstalling.',
    'exportConfig': 'Export configuration',
    'importConfig': 'Import configuration',
    'backupWarning': 'The backup file contains your API keys and passwords in plain text — keep it private and never send it to anyone.',
    'removeVehicleTitle': 'Remove vehicle?',
    'removeVehicleContent': 'Remove {name} and delete its stored credentials?',
    'nothingToBackup': 'Nothing to back up yet.',
    'exportKeysTitle': 'Export contains your keys',
    'exportKeysContentOne': 'This backup file contains your API keys and passwords in plain text — {n} vehicle. Anyone with the file can track your vehicles.\n\nKeep it private: store it somewhere safe and never send it to anyone.',
    'exportKeysContentMany': 'This backup file contains your API keys and passwords in plain text — {n} vehicles. Anyone with the file can track your vehicles.\n\nKeep it private: store it somewhere safe and never send it to anyone.',
    'exportAnyway': 'Export anyway',
    'couldNotReadFile': 'Could not read that file.',
    // v1.5.0: Google Maps API key.
    'mapSettings': 'Map',
    'googleMapsApiKey': 'Google Maps API key',
    'googleMapsApiKeyHint': 'Paste your Google Maps API key',
    'googleMapsApiKeyHelp':
        'With a key, the Map tab shows Google Maps; without one it stays on OpenStreetMap. The key needs “Maps SDK for Android” (and iOS) enabled in Google Cloud Console, with billing enabled. Restrict the key in Google Cloud Console to this app (Android app restriction: package name com.nuvish.unitrack + SHA-1) so nobody else can use it. If Google Maps shows an error, switch back to OpenStreetMap from the Map tab.',
    'googleMapsKeySaved': 'Google Maps key saved.',
    'googleMapsKeyRemoved': 'Google Maps key removed.',
    'googleMapsKeyApplyFailed':
        'Could not apply that key — check it and try again. The map stays on OpenStreetMap.',
    'googleMapsRestartNote':
        'Restart the app for the new key to take effect.',
    'saveKey': 'Save key',
    'clearKey': 'Clear key',
    'couldNotReadBackup': 'Could not read this backup file.',
    'backupNoVehicles': 'This backup has no vehicles to import.',
    'backupNothingNewOne': 'Nothing new — all {n} vehicle is already saved.',
    'backupNothingNewMany': 'Nothing new — all {n} vehicles are already saved.',
    'importedCount': '{n} imported',
    'skippedDuplicateOne': '{n} skipped as duplicate',
    'skippedDuplicateMany': '{n} skipped as duplicates',
    'noVehiclesSavedMessage':
        'Vehicles you add will appear here, with their provider and device ID.',
    'couldNotLoadSaved': "Couldn't load the saved vehicles. {error}",
    'refreshProviders': 'Refresh providers',
    'providerListUpdated': 'Provider list updated.',
    'providerListOffline':
        'Could not reach the provider list — using the built-in providers.',
    'providerListRemote': 'Provider list fetched just now (v{v}).',
    'providerListCached':
        'Provider list from cache (v{v}) — refreshed every 24h.',
    'providerListBuiltin': 'Using the built-in providers — the remote provider list could not be loaded (offline or unavailable).',
    'aboutText': 'Universal GPS tracker — one fleet across Transight, Aargee, LiveTrace, Mercydatrack, Mercydatrack (4G), PauldeaTrack, SimplyTrack and HashTrace.',
    'aboutPrivacy': 'Credentials are stored only on this device, in secure storage. No backend, no analytics.',
    'everySeconds': 'Every {n} seconds',
    'everyMinute': 'Every minute',
    'everyMinutes': 'Every {n} minutes',
    'refreshIntervalNote': '{interval} — providers enforce their own minimum poll interval on top of this (SimplyTrack: 60s, Aargee: 60s).',
    'alertChannelName': 'Vehicle alerts',
    'alertIgnitionOnTitle': '{name} started moving',
    'alertIgnitionOnBody': 'Ignition on · {speed} km/h',
    'alertIgnitionOnBodyNoSpeed': 'Ignition on',
    'alertIgnitionOffTitle': '{name} stopped',
    'alertIgnitionOffBody': 'Ignition off',
    'alertOfflineTitle': '{name} is offline',
    'alertOfflineBody': 'No location updates',
    'alertOverspeedTitle': '{name} is overspeeding',
    'alertOverspeedBody': '{speed} km/h — above 80 km/h',
  },
  'ml': {
    'ok': 'ശരി',
    'cancel': 'റദ്ദാക്കുക',
    'save': 'സംരക്ഷിക്കുക',
    'done': 'ശരി',
    'close': 'അടയ്ക്കുക',
    'retry': 'വീണ്ടും ശ്രമിക്കുക',
    'back': 'തിരികെ',
    'continue': 'തുടരുക',
    'clearAll': 'എല്ലാം മായ്ക്കുക',
    'loading': 'ലോഡ് ചെയ്യുന്നു…',
    'testConnection': 'കണക്ഷൻ പരിശോധിക്കുക',
    'testing': 'പരിശോധിക്കുന്നു…',
    'share': 'പങ്കിടുക',
    'remove': 'നീക്കം ചെയ്യുക',
    'edit': 'എഡിറ്റ് ചെയ്യുക',
    'appTitle': 'UniTrack',
    'appSubtitle': 'എല്ലാ GPS പ്രൊവൈഡർമാരും, ഒരു ഫ്ലീറ്റ്',
    'navFleet': 'ഫ്ലീറ്റ്',
    'navMap': 'മാപ്പ്',
    'navAdd': 'ചേർക്കുക',
    'navSettings': 'ക്രമീകരണങ്ങൾ',
    'searchHint': 'റെഗ് നമ്പർ, IMEI അല്ലെങ്കിൽ പ്രൊവൈഡർ ഉപയോഗിച്ച് തിരയുക',
    'filterAll': 'എല്ലാം',
    'filterLive': 'ലൈവ്',
    'filterIdle': 'നിഷ്ക്രിയം',
    'filterOffline': 'ഓഫ്‌ലൈൻ',
    'filters': 'ഫിൽട്ടറുകൾ',
    'provider': 'പ്രൊവൈഡർ',
    'category': 'വിഭാഗം',
    'emptyFleetTitle': 'വാഹനങ്ങളൊന്നുമില്ല',
    'emptyFleetMessage': 'ഏത് GPS പ്രൊവൈഡറിൽ നിന്നും ഒരു വാഹനം ചേർക്കുക — Transight, Aargee, LiveTrace, Mercydatrack, PauldeaTrack, SimplyTrack അല്ലെങ്കിൽ HashTrace — എല്ലാം ഇവിടെ ട്രാക്ക് ചെയ്യുക.',
    'emptyFleetAction': 'ആദ്യ വാഹനം ചേർക്കുക',
    'noMatchesTitle': 'യോജിക്കുന്നതൊന്നുമില്ല',
    'noMatchesDetail': 'ഫ്ലീറ്റിൽ "{q}" യോജിക്കുന്നതൊന്നുമില്ല. മറ്റൊരു റെഗ് നമ്പറോ പ്രൊവൈഡറോ സ്ഥിതിയോ ശ്രമിക്കുക.',
    'noMatchesMessage':
        'മറ്റൊരു തിരയൽ ശ്രമിക്കുക അല്ലെങ്കിൽ ഫിൽട്ടറുകൾ മായ്ക്കുക.',
    'noMatchesAction': 'തിരയലും ഫിൽട്ടറുകളും മായ്ക്കുക',
    'vehiclesOne': '{n} വാഹനം',
    'vehiclesMany': '{n} വാഹനങ്ങൾ',
    'providersOne': '{n} പ്രൊവൈഡർ',
    'providersMany': '{n} പ്രൊവൈഡറുകൾ',
    'clearSearch': 'തിരയൽ മായ്ക്കുക',
    'speedUnknown': 'വേഗത അറിയില്ല',
    'shareUnavailableCopied': 'പങ്കിടൽ ലഭ്യമല്ല — പകർത്തി.',
    'multiApiTelemetry': 'മൾട്ടി-API ടെലിമെട്രി',
    'refreshErrorTitle': 'ഫ്ലീറ്റ് പുതുക്കാനായില്ല',
    'refreshNow': 'ഇപ്പോൾ പുതുക്കുക',
    'themeToggleLight': 'ലൈറ്റ് തീമിലേക്ക് മാറുക',
    'themeToggleDark': 'ഡാർക്ക് തീമിലേക്ക് മാറുക',
    'updating': 'പുതുക്കുന്നു…',
    'notUpdatedYet': 'ഇതുവരെ പുതുക്കിയിട്ടില്ല',
    'lastUpdateUnknown': 'അവസാന അപ്ഡേറ്റ് അറിയില്ല',
    'navigate': 'നാവിഗേറ്റ്',
    'mapAction': 'മാപ്പ്',
    'live': 'ലൈവ്',
    'idle': 'നിഷ്ക്രിയം',
    'unknown': 'അറിയില്ല',
    'expired': 'കാലാവധി കഴിഞ്ഞു',
    'speed': 'വേഗത',
    'ignition': 'ഇഗ്നിഷൻ',
    'ignitionOn': 'ഓൺ',
    'ignitionOff': 'ഓഫ്',
    'lastSeen': 'അവസാനം കണ്ടത്',
    'justNow': 'ഇപ്പോൾ',
    'minutesAgo': '{n} മിനിറ്റ് മുമ്പ്',
    'hourAgo': '{n} മണിക്കൂർ മുമ്പ്',
    'hoursAgo': '{n} മണിക്കൂർ മുമ്പ്',
    'dayAgo': '{n} ദിവസം മുമ്പ്',
    'daysAgo': '{n} ദിവസം മുമ്പ്',
    'updatedPrefix': '{time} അപ്ഡേറ്റ് ചെയ്തു',
    'today': 'ഇന്ന്',
    'yesterday': 'ഇന്നലെ',
    'allDay': 'ദിവസം മുഴുവൻ',
    'speedKmh': '{n} km/h',
    'categoryBus': 'ബസ്',
    'categoryCar': 'കാർ',
    'categoryTruck': 'ട്രക്ക്',
    'categoryBike': 'ബൈക്ക്',
    'categoryOther': 'മറ്റുള്ളവ',
    'mapEmptyTitle': 'കാണിക്കാൻ വാഹനങ്ങളില്ല',
    'mapEmptyMessage': 'മാപ്പിൽ കാണാൻ ഒരു വാഹനം ചേർക്കുക.',
    'noLocation': 'ഇതുവരെ ലൊക്കേഷനില്ല',
    'liveVehicles': 'ലൈവ് വാഹനങ്ങൾ',
    'allVehicles': 'എല്ലാ വാഹനങ്ങളും',
    'addVehicleTitle': 'വാഹനം ചേർക്കുക',
    'addVehicleSubtitle':
        'ഒരു വാഹനം ട്രാക്ക് ചെയ്യാൻ GPS പ്രൊവൈഡർ ബന്ധിപ്പിക്കുക.',
    'stepProvider': 'പ്രൊവൈഡർ',
    'stepCredentials': 'ക്രെഡൻഷ്യലുകൾ',
    'stepDetails': 'വിശദാംശങ്ങൾ',
    'step1Title': 'ഈ വാഹനം ഏത് GPS പ്രൊവൈഡറിലാണ്?',
    'step1Hint':
        'നിങ്ങളുടെ ട്രാക്കർ റിപ്പോർട്ട് ചെയ്യുന്ന പ്രൊവൈഡർ തിരഞ്ഞെടുക്കുക.',
    'step2Title': '{provider} ക്രെഡൻഷ്യലുകൾ നൽകുക',
    'step2Hint': 'നിങ്ങളുടെ കീകൾ ഈ ഉപകരണത്തിൽ മാത്രമേ സൂക്ഷിക്കൂ.',
    'step3Title': 'ഈ വാഹനത്തിന് പേര് നൽകുക',
    'step3Hint':
        'രജിസ്ട്രേഷൻ നമ്പർ ഉപയോഗിക്കുക — അത് ഫ്ലീറ്റ് ലിസ്റ്റിൽ കാണിക്കും.',
    'displayNameLabel': 'പ്രദർശന നാമം',
    'displayNameHint': 'ഉദാ. KL01AB1234',
    'categoryField': 'വിഭാഗം',
    'enterNameError': 'ഒരു പ്രദർശന നാമം നൽകുക',
    'enterSecretError': 'നിങ്ങളുടെ {label} നൽകുക',
    'testBeforeSave': 'സംരക്ഷിക്കുന്നതിന് മുമ്പ് കണക്ഷൻ പരിശോധിക്കുക',
    'saveVehicle': 'വാഹനം സംരക്ഷിക്കുക',
    'addAnother': 'മറ്റൊന്ന് ചേർക്കുക',
    'vehicleSaved': 'വാഹനം സംരക്ഷിച്ചു',
    'connectionOk': 'കണക്ഷൻ ശരിയാണ്',
    'connectionFailed': 'കണക്ഷൻ പരാജയപ്പെട്ടു',
    'vehicleNotFound': 'വാഹനം കണ്ടെത്തിയില്ല',
    'detailTitle': 'വാഹന വിശദാംശങ്ങൾ',
    'status': 'സ്ഥിതി',
    'vehicleId': 'വാഹന ഐഡി',
    'providerLabel': 'പ്രൊവൈഡർ',
    'lastUpdated': 'അവസാനം അപ്ഡേറ്റ് ചെയ്തത്',
    'coordinates': 'കോർഡിനേറ്റുകൾ',
    'todaysTrip': 'ഇന്നത്തെ യാത്ര',
    'todaysRoute': 'ഇന്നത്തെ റൂട്ട്',
    'history': 'ചരിത്രം',
    'distance': 'ദൂരം',
    'drivingTime': 'ഡ്രൈവിങ്',
    'stops': 'നിർത്തലുകൾ',
    'start': 'ആരംഭം',
    'end': 'അവസാനം',
    'topSpeed': 'പരമാവധി വേഗത',
    'noTripsToday': 'ഇന്ന് യാത്രകളില്ല',
    'noTripsMessage': 'ഈ വാഹനം ഇന്ന് ഇതുവരെ നീങ്ങിയിട്ടില്ല.',
    'noHistory': 'ചരിത്രം ലഭ്യമല്ല',
    'historyUnavailable': 'ഈ പ്രൊവൈഡറിന് ചരിത്രം ലഭ്യമല്ല.',
    'historyError': 'ചരിത്രം ലോഡ് ചെയ്യാനായില്ല',
    'removeVehicle': 'വാഹനം നീക്കം ചെയ്യുക',
    'removeVehicleConfirm': '{name} UniTrack-ൽ നിന്ന് നീക്കം ചെയ്യണോ?',
    'vehicleRemoved': 'വാഹനം നീക്കം ചെയ്തു',
    'shareVehicle': 'വാഹനം പങ്കിടുക',
    'openInMaps': 'മാപ്പിൽ തുറക്കുക',
    'copied': 'പകർത്തി',
    'settingsTitle': 'ക്രമീകരണങ്ങൾ',
    'appearance': 'രൂപം',
    'themeMode': 'തീം',
    'themeSystem': 'സിസ്റ്റം',
    'themeLight': 'ലൈറ്റ്',
    'themeDark': 'ഡാർക്ക്',
    'colourTheme': 'നിറത്തീം',
    'colourThemeSubtitle':
        'ഒരു നിറം തിരഞ്ഞെടുക്കുക — ആപ്പ് മുഴുവൻ അതിനനുസരിച്ച് മാറും',
    'language': 'ഭാഷ',
    'languageSystem': 'സിസ്റ്റം',
    'languageEnglish': 'English',
    'languageMalayalam': 'മലയാളം',
    'notifications': 'അറിയിപ്പുകൾ',
    'vehicleAlerts': 'വാഹന അലേർട്ടുകൾ',
    'vehicleAlertsSubtitle': 'എന്റെ വാഹനങ്ങളെക്കുറിച്ച് എന്നെ അറിയിക്കുക',
    'ignitionChanges': 'ഇഗ്നിഷൻ മാറ്റങ്ങൾ',
    'ignitionChangesSubtitle':
        'ഒരു വാഹനം സ്റ്റാർട്ട് ചെയ്യുമ്പോഴോ നിർത്തുമ്പോഴോ',
    'overspeed': 'അമിതവേഗത (80 km/h-ന് മുകളിൽ)',
    'overspeedSubtitle': 'ഓടുന്ന വാഹനം 80 km/h കടക്കുമ്പോൾ',
    'offlineAlerts': 'ഓഫ്‌ലൈൻ അലേർട്ടുകൾ',
    'offlineAlertsSubtitle': 'ഒരു വാഹനം റിപ്പോർട്ട് നിർത്തുമ്പോൾ',
    'shareApp': 'UniTrack പങ്കിടുക',
    'shareAppSubtitle': 'ആപ്പ് ലിങ്ക് ആർക്കെങ്കിലും അയയ്ക്കുക',
    'data': 'ഡാറ്റ',
    'backupRestore': 'ബാക്കപ്പ് & പുനഃസ്ഥാപിക്കൽ',
    'exportBackup': 'ബാക്കപ്പ് എക്സ്പോർട്ട് ചെയ്യുക',
    'exportBackupSubtitle':
        'പിന്നീട് ഇംപോർട്ട് ചെയ്യാൻ വാഹനങ്ങൾ ഫയലായി സംരക്ഷിക്കുക',
    'importBackup': 'ബാക്കപ്പ് ഇംപോർട്ട് ചെയ്യുക',
    'importBackupSubtitle': 'ബാക്കപ്പ് ഫയലിൽ നിന്ന് വാഹനങ്ങൾ പുനഃസ്ഥാപിക്കുക',
    'refreshInterval': 'പുതുക്കൽ ഇടവേള',
    'refreshIntervalSubtitle': 'ഫ്ലീറ്റ് എത്ര ഇടവിട്ട് പരിശോധിക്കണം',
    'savedVehicles': 'സംരക്ഷിച്ച വാഹനങ്ങൾ',
    'providers': 'പ്രൊവൈഡറുകൾ',
    'providerVerified': 'പരിശോധിച്ചു',
    'providerSetupNeeded': 'സജ്ജീകരണം വേണം',
    'about': 'കുറിച്ച്',
    'aboutUniTrack': 'UniTrack എല്ലാ GPS പ്രൊവൈഡർമാരിലുമുള്ള എല്ലാ വാഹനങ്ങളെയും ഒരിടത്ത് ട്രാക്ക് ചെയ്യുന്നു.',
    'versionLabel': 'പതിപ്പ് {v}',
    'exportFailed': 'എക്സ്പോർട്ട് പരാജയപ്പെട്ടു',
    'importFailed': 'ഇംപോർട്ട് പരാജയപ്പെട്ടു',
    'backupImported': 'ബാക്കപ്പ് ഇംപോർട്ട് ചെയ്തു',
    'backupExported': 'ബാക്കപ്പ് എക്സ്പോർട്ട് ചെയ്തു',
    'noSavedVehicles': 'ഇതുവരെ വാഹനങ്ങൾ സംരക്ഷിച്ചിട്ടില്ല',
    'intervalSeconds': '{n} സെക്കൻഡ്',
    'intervalMinutes': '{n} മിനിറ്റ്',
    'previousStep': 'മുൻപത്തെ ഘട്ടം',
    'testAndSave': 'പരിശോധിച്ച് സംരക്ഷിക്കുക',
    'testAgain': 'വീണ്ടും പരിശോധിക്കുക',
    'saving': 'സംരക്ഷിക്കുന്നു…',
    'testFirstNote': 'ആദ്യം കണക്ഷൻ പരിശോധിക്കുക — വിജയകരമായ പരിശോധനയ്ക്ക് ശേഷം സംരക്ഷിക്കാം.',
    'step1Hint2': 'ഓരോ പ്രൊവൈഡർക്കും സ്വന്തം API ഉണ്ട്. വാഹനത്തിന്റെ ട്രാക്കർ രജിസ്റ്റർ ചെയ്തിരിക്കുന്നത് തിരഞ്ഞെടുക്കുക.',
    'authApiKey': 'ഒരു API കീ ഉപയോഗിച്ച് സൈൻ ഇൻ ചെയ്യുന്നു',
    'authUserIdAndKey': 'യൂസർ ഐഡിയും കീയും ഉപയോഗിച്ച് സൈൻ ഇൻ ചെയ്യുന്നു',
    'authUsernamePassword':
        'യൂസർനെയിമും പാസ്‌വേഡും ഉപയോഗിച്ച് സൈൻ ഇൻ ചെയ്യുന്നു',
    'authDefault': 'സ്വന്തം ക്രെഡൻഷ്യലുകൾ ഉപയോഗിച്ച് സൈൻ ഇൻ ചെയ്യുന്നു',
    'livePlusHistory': 'ലൈവ് ട്രാക്കിങ് + ചരിത്രം',
    'liveOnly': 'ലൈവ് ട്രാക്കിങ് മാത്രം (ചരിത്രമില്ല)',
    'remoteBadge': 'റിമോട്ട്',
    'step2Subtitle':
        'ഇവ ഈ ഉപകരണത്തിൽ മാത്രമേ, സുരക്ഷിത സംഭരണത്തിൽ, സൂക്ഷിക്കൂ.',
    'notVerifiedWarning': '{provider} ഇതുവരെ പരിശോധിച്ചിട്ടില്ല — അതിന്റെ എൻഡ്പോയിന്റ് പാത്തുകൾ സ്ഥിരീകരിച്ചിട്ടില്ല. കണക്ഷൻ പരിശോധനയിൽ എന്താണ് കുറവെന്ന് വിശദീകരിക്കും.',
    'deviceIdHelper': 'പ്രൊവൈഡറിൽ ഈ വാഹനത്തെ ഇത് തിരിച്ചറിയുന്നു.',
    'secretHelper':
        'ഒരിക്കലും പങ്കിടില്ല — ഈ ഉപകരണത്തിൽ മാത്രം സംരക്ഷിക്കുന്നു.',
    'required': 'ആവശ്യമാണ്',
    'hide': 'മറയ്ക്കുക',
    'show': 'കാണിക്കുക',
    'regNoLabel': 'രജിസ്ട്രേഷൻ നമ്പർ (ഓപ്ഷണൽ)',
    'regNoHint': 'പ്രദർശനത്തിനും ഫോൾബാക്ക് പൊരുത്തത്തിനും ഉപയോഗിക്കുന്നു',
    'displayNameOptionalLabel': 'പ്രദർശന നാമം (ഓപ്ഷണൽ)',
    'displayNameOptionalHint': 'ഫ്ലീറ്റ് ലിസ്റ്റിനുള്ള സൗഹൃദ നാമം',
    'vehicleType': 'വാഹന തരം',
    'vehicleTypeHint': 'ഫ്ലീറ്റ് കാർഡുകളിലും മാപ്പിലും ഐക്കണായി കാണിക്കും.',
    'testStepTitle': 'കണക്ഷൻ പരിശോധിക്കുക',
    'testStepHint': 'സംരക്ഷിക്കുന്നതിന് മുമ്പ് ഈ ക്രെഡൻഷ്യലുകൾ ഉപയോഗിച്ച് {provider}-നെ ബന്ധപ്പെടും.',
    'testIdleHint': '"Test connection" ടാപ്പ് ചെയ്യുക — പ്രൊവൈഡർ നിങ്ങളുടെ വാഹനവുമായി മറുപടി നൽകിയാൽ, സംരക്ഷിക്കാം.',
    'contactingProvider': 'പ്രൊവൈഡറെ ബന്ധപ്പെടുന്നു…',
    'connectedTitle': 'കണക്റ്റഡ്!',
    'vehiclesFoundOne': '{provider}-ൽ {n} വാഹനം കണ്ടെത്തി.',
    'vehiclesFoundMany': '{provider}-ൽ {n} വാഹനങ്ങൾ കണ്ടെത്തി.',
    'unknownError': 'അറിയാത്ത പിശക്.',
    'whatToCheck': 'എന്താണ് പരിശോധിക്കേണ്ടത്:',
    'checkApiKey': '• API കീ / പാസ്‌വേഡ് ശരിയായി പകർത്തിയിട്ടുണ്ട്',
    'checkDeviceId': '• ഡിവൈസ് ഐഡി പ്രൊവൈഡർ അക്കൗണ്ടുമായി യോജിക്കുന്നു',
    'checkRegistered': '• ഈ അക്കൗണ്ടിന് കീഴിൽ വാഹനം രജിസ്റ്റർ ചെയ്തിട്ടുണ്ട്',
    'credentialsPrivacy': 'ക്രെഡൻഷ്യലുകൾ ഈ ഉപകരണത്തിൽ മാത്രമേ, സുരക്ഷിത സംഭരണത്തിൽ, സൂക്ഷിക്കൂ. പ്രൊവൈഡറിന്റെ സ്വന്തം API ഒഴികെ മറ്റെവിടെയും അപ്‌ലോഡ് ചെയ്യില്ല.',
    'noVehiclesError': 'കണക്റ്റഡ്, പക്ഷേ അക്കൗണ്ട് വാഹനങ്ങളൊന്നും നൽകിയില്ല. ഡിവൈസ് ഐഡി പരിശോധിക്കുക — ഈ അക്കൗണ്ടിന് കീഴിൽ രജിസ്റ്റർ ചെയ്ത വാഹനവുമായി യോജിക്കണം.',
    'notSupportedYet': 'ഇതുവരെ പിന്തുണയ്ക്കുന്നില്ല.',
    'timeoutError': 'പ്രൊവൈഡർ മറുപടി നൽകാൻ വളരെ സമയമെടുത്തു. ഇന്റർനെറ്റ് കണക്ഷൻ പരിശോധിച്ച് വീണ്ടും ടെസ്റ്റ് ടാപ്പ് ചെയ്യുക.',
    'unreachableError': '{provider}-നെ ബന്ധപ്പെടാനായില്ല — ഇന്റർനെറ്റ് കണക്ഷൻ പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.',
    'unexpectedResponseError': 'പ്രൊവൈഡർ അപ്രതീക്ഷിത പ്രതികരണം നൽകി. വീണ്ടും ശ്രമിക്കുക, അല്ലെങ്കിൽ API കീ പരിശോധിക്കുക.',
    'connectionFailedDetail': 'കണക്ഷൻ പരാജയപ്പെട്ടു: {error}',
    'backToFleet': 'ഫ്ലീറ്റിലേക്ക് തിരികെ',
    'liveLocationHint': 'ലൈവ് ലൊക്കേഷൻ — മുഴുവൻ മാപ്പിനായി ടാപ്പ് ചെയ്യുക',
    'coordinatesCopied': 'കോർഡിനേറ്റുകൾ പകർത്തി.',
    'historyLoadError': 'ചരിത്രം ലോഡ് ചെയ്യാനായില്ല: {error}',
    'ignitionOnRunning': 'ഓൺ • ഓടുന്നു',
    'ignitionOffParked': 'ഓഫ് • പാർക്ക് ചെയ്തു',
    'vehicleSection': 'വാഹനം',
    'typeLabel': 'തരം',
    'regNoLabel2': 'റെഗ് നമ്പർ',
    'locationLabel': 'ലൊക്കേഷൻ',
    'noFixYet': 'ഇതുവരെ ഫിക്സില്ല',
    'copyCoordinates': 'കോർഡിനേറ്റുകൾ പകർത്തുക',
    'providerTime': 'പ്രൊവൈഡർ സമയം: {time}',
    'historyNotSupported': '{provider} ചരിത്രം പിന്തുണയ്ക്കുന്നില്ല — ലൈവ് സ്നാപ്പ്ഷോട്ടുകൾ മാത്രമേ നൽകൂ.',
    'loadTodaysRoute': 'ഇന്നത്തെ റൂട്ട് ലോഡ് ചെയ്യുക',
    'pointsTodayOne': 'ഇന്ന് {n} പോയിന്റ്',
    'pointsTodayMany': 'ഇന്ന് {n} പോയിന്റുകൾ',
    'pointsTodayLogOne': 'ഇന്ന് {n} പോയിന്റ് · ലോക്കൽ ട്രിപ്പ് ലോഗ്',
    'pointsTodayLogMany': 'ഇന്ന് {n} പോയിന്റുകൾ · ലോക്കൽ ട്രിപ്പ് ലോഗ്',
    'noTripData': 'ഇന്ന് ഇതുവരെ യാത്രാ ഡാറ്റയില്ല — ആപ്പ് പോൾ ചെയ്യുമ്പോൾ സ്ഥാനങ്ങൾ രേഖപ്പെടുത്തും. ഒരു ഡ്രൈവിന് ശേഷം വീണ്ടും പരിശോധിക്കുക.',
    'idling': 'ഐഡ്ലിങ്',
    'stopped': 'നിർത്തിയത്',
    'exportCsv': 'ഇന്നത്തേത് CSV ആയി എക്സ്പോർട്ട് ചെയ്യുക',
    'reportShared': 'റിപ്പോർട്ട് പങ്കിട്ടു — ഷെയർ ഷീറ്റിൽ നിന്ന് സംരക്ഷിക്കുക.',
    'viewDetails': 'വിശദാംശങ്ങൾ കാണുക',
    'ignitionUnknown': 'ഇഗ്നിഷൻ അറിയില്ല',
    'ignitionOnText': 'ഇഗ്നിഷൻ ഓൺ',
    'ignitionOffText': 'ഇഗ്നിഷൻ ഓഫ്',
    'noVehiclesWithLocation': 'ഇതുവരെ ലൊക്കേഷനുള്ള വാഹനങ്ങളില്ല.',
    'mapCountLabel': '{live} ലൈവ് · {idle} നിഷ്ക്രിയം · ആകെ {total}',
    'fitAllVehicles': 'എല്ലാ വാഹനങ്ങളും ഉൾക്കൊള്ളിക്കുക',
    'centreOnLive': 'ലൈവ് വാഹനത്തിൽ കേന്ദ്രീകരിക്കുക',
    'mapEmptyTitle2': 'മാപ്പിൽ ഇതുവരെ വാഹനങ്ങളില്ല',
    'mapEmptyMessage2':
        'ഒരു വാഹനം ചേർക്കുക, അതിന്റെ ലൈവ് ലൊക്കേഷൻ ഇവിടെ കാണിക്കും.',
    'noLocationsYet': 'ഇതുവരെ കാണിക്കാൻ ലൊക്കേഷനുകളില്ല — പ്രൊവൈഡർമാർ ഈ വാഹനങ്ങൾക്ക് ഫിക്സ് നൽകിയിട്ടില്ല.',
    // v1.5.0: map type + Google Maps.
    'mapTypeOsm': 'OpenStreetMap',
    'mapTypeGoogle': 'Google Maps',
    'loadingGoogleMap': 'Google Maps ലോഡ് ചെയ്യുന്നു…',
    'shareLiveLocation': 'ലൈവ് ലൊക്കേഷൻ പങ്കിടുക',
    'shareLiveLocationShort': 'പങ്കിടുക',
    'shareLiveLocationText': '{name} — ലൈവ് ലൊക്കേഷൻ: {url}',
    // v1.5.0: trip playback.
    'playTrip': 'യാത്ര പ്ലേ ചെയ്യുക',
    'pauseTrip': 'യാത്ര താൽക്കാലികമായി നിർത്തുക',
    'tripPlayback': 'യാത്ര പ്ലേബാക്ക്',
    'tripPlaybackNotAvailable':
        'ഈ പ്രൊവൈഡറിന് യാത്ര പ്ലേബാക്ക് ലഭ്യമല്ല — ഇത് യാത്രാ ചരിത്രം പങ്കിടുന്നില്ല.',
    'playbackPoint': '{total} ൽ {index}-ആം പോയിന്റ്',
    'settingsSubtitle': 'മെറ്റീരിയൽ യൂ തീം, പോളിങ് ഇടവേളകൾ & പ്രൊവൈഡറുകൾ',
    'themeAppliesNote': 'ലൈറ്റ്, ഡാർക്ക് മോഡുകളിൽ ഉടൻ പ്രാബല്യത്തിൽ വരും.',
    'backupCardText': 'ആപ്പ് വീണ്ടും ഇൻസ്റ്റാൾ ചെയ്യുമ്പോൾ സംരക്ഷിച്ച വാഹനങ്ങളും ക്രെഡൻഷ്യലുകളും മാഞ്ഞുപോകും. ആദ്യം ഒരു ബാക്കപ്പ് എക്സ്പോർട്ട് ചെയ്യുക, വീണ്ടും ഇൻസ്റ്റാൾ ചെയ്ത ശേഷം ഇംപോർട്ട് ചെയ്യുക.',
    'exportConfig': 'കോൺഫിഗറേഷൻ എക്സ്പോർട്ട് ചെയ്യുക',
    'importConfig': 'കോൺഫിഗറേഷൻ ഇംപോർട്ട് ചെയ്യുക',
    'backupWarning': 'ബാക്കപ്പ് ഫയലിൽ നിങ്ങളുടെ API കീകളും പാസ്‌വേഡുകളും പ്ലെയിൻ ടെക്സ്റ്റായി ഉണ്ട് — അത് സ്വകാര്യമായി സൂക്ഷിക്കുക, ആർക്കും അയയ്ക്കരുത്.',
    'removeVehicleTitle': 'വാഹനം നീക്കം ചെയ്യണോ?',
    'removeVehicleContent':
        '{name} നീക്കം ചെയ്ത് സംരക്ഷിച്ച ക്രെഡൻഷ്യലുകൾ ഇല്ലാതാക്കണോ?',
    'nothingToBackup': 'ഇതുവരെ ബാക്കപ്പ് ചെയ്യാൻ ഒന്നുമില്ല.',
    'exportKeysTitle': 'എക്സ്പോർട്ടിൽ നിങ്ങളുടെ കീകൾ ഉണ്ട്',
    'exportKeysContentOne': 'ഈ ബാക്കപ്പ് ഫയലിൽ നിങ്ങളുടെ API കീകളും പാസ്‌വേഡുകളും പ്ലെയിൻ ടെക്സ്റ്റായി ഉണ്ട് — {n} വാഹനം. ഫയൽ കൈവശമുള്ള ആർക്കും നിങ്ങളുടെ വാഹനങ്ങൾ ട്രാക്ക് ചെയ്യാം.\n\nസ്വകാര്യമായി സൂക്ഷിക്കുക: സുരക്ഷിതമായ ഒരിടത്ത് വയ്ക്കുക, ആർക്കും അയയ്ക്കരുത്.',
    'exportKeysContentMany': 'ഈ ബാക്കപ്പ് ഫയലിൽ നിങ്ങളുടെ API കീകളും പാസ്‌വേഡുകളും പ്ലെയിൻ ടെക്സ്റ്റായി ഉണ്ട് — {n} വാഹനങ്ങൾ. ഫയൽ കൈവശമുള്ള ആർക്കും നിങ്ങളുടെ വാഹനങ്ങൾ ട്രാക്ക് ചെയ്യാം.\n\nസ്വകാര്യമായി സൂക്ഷിക്കുക: സുരക്ഷിതമായ ഒരിടത്ത് വയ്ക്കുക, ആർക്കും അയയ്ക്കരുത്.',
    'exportAnyway': 'എന്തായാലും എക്സ്പോർട്ട് ചെയ്യുക',
    'couldNotReadFile': 'ആ ഫയൽ വായിക്കാനായില്ല.',
    // v1.5.0: Google Maps API key.
    'mapSettings': 'മാപ്പ്',
    'googleMapsApiKey': 'Google Maps API കീ',
    'googleMapsApiKeyHint': 'നിങ്ങളുടെ Google Maps API കീ ഒട്ടിക്കുക',
    'googleMapsApiKeyHelp':
        'കീ ഉണ്ടെങ്കിൽ മാപ്പ് ടാബിൽ Google Maps കാണിക്കും; ഇല്ലെങ്കിൽ OpenStreetMap തന്നെ തുടരും. കീക്ക് Google Cloud Console-ൽ “Maps SDK for Android” (ഒപ്പം iOS) പ്രവർത്തനക്ഷമമാക്കുകയും ബില്ലിങ് ഓണാക്കുകയും വേണം. മറ്റാർക്കും ഉപയോഗിക്കാനാകാത്ത വിധം കീ Google Cloud Console-ൽ ഈ ആപ്പിലേക്ക് മാത്രമായി പരിമിതപ്പെടുത്തുക (Android ആപ്പ് നിയന്ത്രണം: package name com.nuvish.unitrack + SHA-1). Google Maps പിശക് കാണിച്ചാൽ മാപ്പ് ടാബിൽ നിന്ന് OpenStreetMap-ലേക്ക് മടങ്ങുക.',
    'googleMapsKeySaved': 'Google Maps കീ സംരക്ഷിച്ചു.',
    'googleMapsKeyRemoved': 'Google Maps കീ നീക്കം ചെയ്തു.',
    'googleMapsKeyApplyFailed':
        'ആ കീ പ്രയോഗിക്കാനായില്ല — പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക. മാപ്പ് OpenStreetMap-ൽ തന്നെ തുടരും.',
    'googleMapsRestartNote':
        'പുതിയ കീ പ്രാബല്യത്തിൽ വരാൻ ആപ്പ് വീണ്ടും തുറക്കുക.',
    'saveKey': 'കീ സംരക്ഷിക്കുക',
    'clearKey': 'കീ മായ്ക്കുക',
    'couldNotReadBackup': 'ഈ ബാക്കപ്പ് ഫയൽ വായിക്കാനായില്ല.',
    'backupNoVehicles': 'ഈ ബാക്കപ്പിൽ ഇംപോർട്ട് ചെയ്യാൻ വാഹനങ്ങളില്ല.',
    'backupNothingNewOne':
        'പുതിയതൊന്നുമില്ല — {n} വാഹനവും ഇതിനകം സംരക്ഷിച്ചിട്ടുണ്ട്.',
    'backupNothingNewMany':
        'പുതിയതൊന്നുമില്ല — {n} വാഹനങ്ങളും ഇതിനകം സംരക്ഷിച്ചിട്ടുണ്ട്.',
    'importedCount': '{n} ഇംപോർട്ട് ചെയ്തു',
    'skippedDuplicateOne': '{n} ഡ്യൂപ്ലിക്കേറ്റായി ഒഴിവാക്കി',
    'skippedDuplicateMany': '{n} ഡ്യൂപ്ലിക്കേറ്റുകളായി ഒഴിവാക്കി',
    'noVehiclesSavedMessage': 'നിങ്ങൾ ചേർക്കുന്ന വാഹനങ്ങൾ ഇവിടെ കാണിക്കും, അവയുടെ പ്രൊവൈഡറും ഡിവൈസ് ഐഡിയും സഹിതം.',
    'couldNotLoadSaved': 'സംരക്ഷിച്ച വാഹനങ്ങൾ ലോഡ് ചെയ്യാനായില്ല. {error}',
    'refreshProviders': 'പ്രൊവൈഡറുകൾ പുതുക്കുക',
    'providerListUpdated': 'പ്രൊവൈഡർ ലിസ്റ്റ് അപ്ഡേറ്റ് ചെയ്തു.',
    'providerListOffline': 'പ്രൊവൈഡർ ലിസ്റ്റിൽ എത്താനായില്ല — ബിൽറ്റ്-ഇൻ പ്രൊവൈഡറുകൾ ഉപയോഗിക്കുന്നു.',
    'providerListRemote': 'പ്രൊവൈഡർ ലിസ്റ്റ് ഇപ്പോൾ ലഭിച്ചു (v{v}).',
    'providerListCached': 'കാഷെയിൽ നിന്നുള്ള പ്രൊവൈഡർ ലിസ്റ്റ് (v{v}) — ഓരോ 24 മണിക്കൂറിലും പുതുക്കുന്നു.',
    'providerListBuiltin': 'ബിൽറ്റ്-ഇൻ പ്രൊവൈഡറുകൾ ഉപയോഗിക്കുന്നു — റിമോട്ട് പ്രൊവൈഡർ ലിസ്റ്റ് ലോഡ് ചെയ്യാനായില്ല (ഓഫ്‌ലൈൻ അല്ലെങ്കിൽ ലഭ്യമല്ല).',
    'aboutText': 'യൂണിവേഴ്സൽ GPS ട്രാക്കർ — Transight, Aargee, LiveTrace, Mercydatrack, Mercydatrack (4G), PauldeaTrack, SimplyTrack, HashTrace എന്നിവയിലുടനീളം ഒരു ഫ്ലീറ്റ്.',
    'aboutPrivacy': 'ക്രെഡൻഷ്യലുകൾ ഈ ഉപകരണത്തിൽ മാത്രമേ സൂക്ഷിക്കൂ, സുരക്ഷിത സംഭരണത്തിൽ. ബാക്കെൻഡില്ല, അനലിറ്റിക്സില്ല.',
    'everySeconds': '{n} സെക്കൻഡ് ഇടവിട്ട്',
    'everyMinute': 'ഓരോ മിനിറ്റിലും',
    'everyMinutes': '{n} മിനിറ്റ് ഇടവിട്ട്',
    'refreshIntervalNote': '{interval} — പ്രൊവൈഡർമാർ ഇതിന് മുകളിൽ അവരുടെ കുറഞ്ഞ പോൾ ഇടവേള നടപ്പാക്കും (SimplyTrack: 60s, Aargee: 60s).',
    'alertChannelName': 'വാഹന അലേർട്ടുകൾ',
    'alertIgnitionOnTitle': '{name} നീങ്ങാൻ തുടങ്ങി',
    'alertIgnitionOnBody': 'ഇഗ്നിഷൻ ഓൺ · {speed} km/h',
    'alertIgnitionOnBodyNoSpeed': 'ഇഗ്നിഷൻ ഓൺ',
    'alertIgnitionOffTitle': '{name} നിന്നു',
    'alertIgnitionOffBody': 'ഇഗ്നിഷൻ ഓഫ്',
    'alertOfflineTitle': '{name} ഓഫ്‌ലൈനാണ്',
    'alertOfflineBody': 'ലൊക്കേഷൻ അപ്ഡേറ്റുകളില്ല',
    'alertOverspeedTitle': '{name} അമിതവേഗത്തിലാണ്',
    'alertOverspeedBody': '{speed} km/h — 80 km/h-ന് മുകളിൽ',
  },
};
