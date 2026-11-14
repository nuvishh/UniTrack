import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../l10n/app_localizations.dart';
import 'alert_rules.dart';

/// Local vehicle-alert notifications — no server, works offline.
///
/// Same plugin + init pattern as the sibling Duezy app
/// (flutter_local_notifications ^19.4.0):
/// `AndroidInitializationSettings('@mipmap/ic_launcher')` and the
/// Android 13+ permission request via the plugin.
///
/// The service is a no-op until [ensureInitialized] completes, so
/// the poll loop can call [showAlerts] freely (including in tests,
/// where the plugin is never initialised). A failed show never
/// throws into the poll loop.
///
/// NOTE: on the user's Redmi 12 5G, MIUI is known to block
/// notification delivery for other apps too (Duezy's scheduled
/// alarms never fire despite all permissions green). These alerts
/// are implemented properly, but on-device delivery is uncertain —
/// the in-app fleet state stays the source of truth.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// True once [ensureInitialized] has completed.
  bool get isInitialized => _initialized;

  /// Android notification channel id for vehicle alerts.
  static const channelId = 'unitrack_alerts';

  /// Initialises the plugin and asks for the notification
  /// permission (Android 13+ / iOS). Safe to call repeatedly.
  /// Never throws: on a platform without the plugin (e.g. widget
  /// tests) it stays uninitialised and [showAlerts] stays a no-op.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _initialized = true;
    } catch (_) {
      // No notification platform — alerts stay disabled.
    }
  }

  /// Shows one local notification per alert, in [locale].
  Future<void> showAlerts(
    List<VehicleAlert> alerts, {
    required Locale locale,
  }) async {
    if (!_initialized || alerts.isEmpty) return;
    final l10n = AppLocalizations(locale);
    for (final alert in alerts) {
      final (String title, String body) = switch (alert.kind) {
        AlertKind.ignitionOn => (
          l10n.alertIgnitionOnTitle(alert.vehicle.displayName),
          l10n.alertIgnitionOnBody(alert.speedKmph),
        ),
        AlertKind.ignitionOff => (
          l10n.alertIgnitionOffTitle(alert.vehicle.displayName),
          l10n.alertIgnitionOffBody(),
        ),
        AlertKind.offline => (
          l10n.alertOfflineTitle(alert.vehicle.displayName),
          l10n.alertOfflineBody(),
        ),
        AlertKind.overspeed => (
          l10n.alertOverspeedTitle(alert.vehicle.displayName),
          l10n.alertOverspeedBody(alert.speedKmph ?? 0),
        ),
      };
      try {
        await _plugin.show(
          '${alert.vehicle.providerKey}:${alert.vehicle.id}:${alert.kind.name}'
              .hashCode,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              l10n.alertChannelName,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      } catch (_) {
        // A failed notification must never break the poll loop.
      }
    }
  }
}
