import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/models/vehicle.dart';
import 'package:unitrack/services/alert_rules.dart';
import 'package:unitrack/services/notification_service.dart';

void main() {
  test('showAlerts is a no-op before initialisation', () async {
    final service = NotificationService();
    expect(service.isInitialized, isFalse);
    await service.showAlerts([
      const VehicleAlert(
        kind: AlertKind.ignitionOn,
        vehicle: Vehicle(
          id: 'KL01AB1234',
          displayName: 'KL01AB1234',
          providerKey: 'aargee',
          status: VehicleStatus.live,
        ),
        speedKmph: 42,
      ),
    ], locale: const Locale('en'));
    // Completing without throwing is the whole assertion: with no
    // plugin initialised, nothing may reach the platform channel.
  });

  test('ensureInitialized does not throw without a platform plugin', () async {
    final service = NotificationService();
    await service.ensureInitialized();
    // No platform implementation exists in tests, so the service
    // stays uninitialised instead of crashing the app start.
    expect(service.isInitialized, isFalse);
  });
}
