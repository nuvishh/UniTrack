import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unitrack/models/saved_vehicle.dart';
import 'package:unitrack/models/trip_point.dart';
import 'package:unitrack/models/vehicle.dart';
import 'package:unitrack/models/vehicle_category.dart';
import 'package:unitrack/providers/storage_provider.dart';
import 'package:unitrack/providers/trip_log_provider.dart';
import 'package:unitrack/screens/vehicle_detail_screen.dart';
import 'package:unitrack/services/secure_storage_service.dart';
import 'package:unitrack/theme/app_theme.dart';

// All values below are FAKE examples — never real reg numbers, IMEIs,
// vehicle ids or keys.

class _FakeStorage extends SecureStorageService {
  @override
  Future<List<SavedVehicle>> loadVehicles() async => const [];

  @override
  Future<Duration> getRefreshInterval() async =>
      const Duration(seconds: 60);

  @override
  Future<void> setRefreshInterval(Duration interval) async {}

  @override
  Future<String?> readSecret(String vehicleId) async => null;
}

/// A trip log that serves a fixed set of points and never records.
class _TestTripLog extends TripLogNotifier {
  _TestTripLog(this.log);

  final Map<String, List<TripPoint>> log;

  @override
  Map<String, List<TripPoint>> build() => log;
}

const _vehicle = Vehicle(
  id: '860000000000001',
  displayName: 'KL00XX0001',
  providerKey: 'aargee',
  status: VehicleStatus.live,
  category: VehicleCategory.truck,
);

Future<void> _pumpDetail(
  WidgetTester tester,
  Map<String, List<TripPoint>> log,
) async {
  // Tall surface: the detail screen scrolls and the "Today's trip"
  // section sits below the fold on a phone-sized surface.
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(_FakeStorage()),
        tripLogProvider.overrideWith(() => _TestTripLog(log)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const VehicleDetailScreen(vehicle: _vehicle),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('detail shows category + Today\'s trip section', (tester) async {
    final now = DateTime.now();
    // Three points, 2 minutes apart, 0.01 degrees (~1.11 km) apart,
    // driving at 60 km/h — 2.2 km and 4 minutes of driving today.
    final log = {
      vehicleKey('aargee', '860000000000001'): [
        TripPoint(
          time: now.subtract(const Duration(minutes: 4)),
          latitude: 12.0,
          longitude: 75.0,
          speedKmph: 60,
          ignition: true,
        ),
        TripPoint(
          time: now.subtract(const Duration(minutes: 2)),
          latitude: 12.01,
          longitude: 75.0,
          speedKmph: 60,
          ignition: true,
        ),
        TripPoint(
          time: now,
          latitude: 12.02,
          longitude: 75.0,
          speedKmph: 60,
          ignition: true,
        ),
      ],
    };
    await _pumpDetail(tester, log);

    // Category in the header.
    expect(find.text('Truck'), findsWidgets);
    expect(find.byIcon(Icons.local_shipping), findsWidgets);
    // The compact day report moved here from the old Reports tab.
    expect(find.text("Today's trip"), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('2.2 km'), findsOneWidget);
    expect(find.text('Driving'), findsOneWidget);
    expect(find.text('4m'), findsOneWidget);
    expect(find.text('Export today as CSV'), findsOneWidget);
  });

  testWidgets('detail shows the empty trip state with no points today',
      (tester) async {
    await _pumpDetail(tester, {});
    expect(find.text("Today's trip"), findsOneWidget);
    expect(
      find.textContaining('No trip data today yet'),
      findsOneWidget,
    );
  });
}
