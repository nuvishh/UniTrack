import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unitrack/models/saved_vehicle.dart';
import 'package:unitrack/models/vehicle.dart';
import 'package:unitrack/models/vehicle_category.dart';
import 'package:unitrack/providers/storage_provider.dart';
import 'package:unitrack/providers/tracker_provider.dart';
import 'package:unitrack/screens/fleet_list_screen.dart';
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

/// A tracker that serves a fixed fleet and never polls.
class _FakeTracker extends TrackerNotifier {
  _FakeTracker(this.vehicles);

  final List<Vehicle> vehicles;

  @override
  TrackerState build() => TrackerState(vehicles: vehicles);
}

const _bus = Vehicle(
  id: '860000000000001',
  displayName: 'KL00XX0001',
  providerKey: 'aargee',
  speedKmph: 40,
  ignition: true,
  status: VehicleStatus.live,
  category: VehicleCategory.bus,
);
const _car = Vehicle(
  id: '10001',
  displayName: 'KL00XX0002',
  providerKey: 'hashtrace',
  speedKmph: 0,
  ignition: false,
  status: VehicleStatus.idle,
  category: VehicleCategory.car,
);
const _truck = Vehicle(
  id: '860000000000003',
  displayName: 'KL00XX0003',
  providerKey: 'transight',
  status: VehicleStatus.unknown,
  category: VehicleCategory.truck,
);

Future<void> _pumpFleet(WidgetTester tester) async {
  // Wide + tall surface: ListView.builder only builds on-screen
  // cards, and the filter chip rows scroll horizontally on a
  // phone-sized surface, so a narrow surface would hide cards and
  // chips from finders. The smoke tests cover phone widths.
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(_FakeStorage()),
        trackerProvider.overrideWith(() => _FakeTracker([_bus, _car, _truck])),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const FleetListScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Opens the Filters bottom sheet via the tune button in the
/// compact filter bar, and lets its entrance animation finish.
Future<void> _openFilterSheet(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.tune));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// A fleet card's reg no — scoped to the list, because the same text
/// also sits in the search field once a query is typed.
Finder _card(String regNo) => find.descendant(
      of: find.byType(ListView),
      matching: find.text(regNo),
    );

void main() {
  testWidgets('category chips filter the fleet', (tester) async {
    await _pumpFleet(tester);

    // All three cards render; the category chips are NOT on the
    // Fleet screen any more (v1.3.1) — they live in the Filters
    // sheet behind the tune button.
    expect(_card('KL00XX0001'), findsOneWidget);
    expect(_card('KL00XX0002'), findsOneWidget);
    expect(_card('KL00XX0003'), findsOneWidget);
    expect(find.text('Bus (1)'), findsNothing);
    expect(find.text('Car (1)'), findsNothing);
    expect(find.text('Truck (1)'), findsNothing);

    await _openFilterSheet(tester);
    expect(find.text('Bus (1)'), findsOneWidget);
    expect(find.text('Car (1)'), findsOneWidget);
    expect(find.text('Truck (1)'), findsOneWidget);
    // Category icons show on the cards (and the chips).
    expect(find.byIcon(Icons.directions_bus), findsWidgets);
    expect(find.byIcon(Icons.directions_car), findsWidgets);
    expect(find.byIcon(Icons.local_shipping), findsWidgets);

    await tester.tap(find.text('Bus (1)'));
    await tester.pump();
    expect(_card('KL00XX0001'), findsOneWidget);
    expect(_card('KL00XX0002'), findsNothing);
    expect(_card('KL00XX0003'), findsNothing);

    await tester.tap(find.text('Car (1)'));
    await tester.pump();
    expect(_card('KL00XX0002'), findsOneWidget);
    expect(_card('KL00XX0001'), findsNothing);

    // The sheet holds two 'All (3)' chips (provider + category)
    // and the bar a third — the category section's is scoped by key.
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('filterCategorySection')),
        matching: find.text('All (3)'),
      ),
    );
    await tester.pump();
    expect(_card('KL00XX0001'), findsOneWidget);
    expect(_card('KL00XX0002'), findsOneWidget);
    expect(_card('KL00XX0003'), findsOneWidget);
  });

  testWidgets('category filter combines with search', (tester) async {
    await _pumpFleet(tester);

    await tester.enterText(find.byType(TextField), 'KL00XX0002');
    await tester.pump();
    expect(_card('KL00XX0002'), findsOneWidget);
    expect(_card('KL00XX0001'), findsNothing);

    // Search narrows to the car, but the Bus filter excludes it.
    await _openFilterSheet(tester);
    await tester.tap(find.text('Bus (1)'));
    await tester.pump();
    expect(find.text('No matches'), findsOneWidget);

    // The Car filter + the same search still matches the car.
    await tester.tap(find.text('Car (1)'));
    await tester.pump();
    expect(_card('KL00XX0002'), findsOneWidget);
  });

  testWidgets('category filter combines with status filter', (tester) async {
    await _pumpFleet(tester);

    // The 'Idle' chip selects idle-status vehicles — the car.
    await tester.tap(find.text('Idle (1)'));
    await tester.pump();
    expect(_card('KL00XX0002'), findsOneWidget);
    expect(_card('KL00XX0001'), findsNothing);

    // Bus filter + Idle status = nothing matches.
    await _openFilterSheet(tester);
    await tester.tap(find.text('Bus (1)'));
    await tester.pump();
    expect(find.text('No matches'), findsOneWidget);

    // The Car filter + the same status still matches the car.
    await tester.tap(find.text('Car (1)'));
    await tester.pump();
    expect(_card('KL00XX0002'), findsOneWidget);
  });

  testWidgets('status chips use the summary taxonomy: Live/Idle/Offline',
      (tester) async {
    await _pumpFleet(tester);

    // One live bus, one idle (ignition-off) car, one offline truck:
    // the counts on the chips match the summary strip and the card
    // badges — the idle car is "Idle", never "Stopped".
    expect(find.text('Live (1)'), findsOneWidget);
    expect(find.text('Idle (1)'), findsOneWidget);
    expect(find.text('Offline (1)'), findsOneWidget);
    expect(find.text('Stopped (1)'), findsNothing);
    expect(find.text('Moving (1)'), findsNothing);
    // Status chips stay in the compact bar; provider/category chips
    // are in the sheet, not on the screen.
    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(find.text('Bus (1)'), findsNothing);
    expect(find.text('Aargee GPS (1)'), findsNothing);

    // The Idle chip shows the ignition-off car (its card badge also
    // reads Idle), and the Live chip shows only the bus.
    await tester.tap(find.text('Idle (1)'));
    await tester.pump();
    expect(_card('KL00XX0002'), findsOneWidget);
    expect(_card('KL00XX0001'), findsNothing);
    expect(_card('KL00XX0003'), findsNothing);

    // 'All (3)' is unique while the sheet is closed — it is only
    // the bar's status chip now.
    await tester.tap(find.text('All (3)'));
    await tester.pump();
    await tester.tap(find.text('Live (1)'));
    await tester.pump();
    expect(_card('KL00XX0001'), findsOneWidget);
    expect(_card('KL00XX0002'), findsNothing);

    await tester.tap(find.text('All (3)'));
    await tester.pump();
    await tester.tap(find.text('Offline (1)'));
    await tester.pump();
    expect(_card('KL00XX0003'), findsOneWidget);
    expect(_card('KL00XX0001'), findsNothing);
  });

  testWidgets(
      'provider chips live in the filter sheet, not on the fleet screen',
      (tester) async {
    await _pumpFleet(tester);

    // No provider or category chips on the Fleet screen by default
    // (v1.3.1) — only the status chips in the compact bar.
    expect(find.text('Aargee GPS (1)'), findsNothing);
    expect(find.text('HashTrace Tracker (1)'), findsNothing);
    expect(find.text('Transight GPS (1)'), findsNothing);
    expect(find.text('Bus (1)'), findsNothing);
    // The tune button is there, with no badge while no provider /
    // category filter is active.
    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(find.byKey(const Key('filterBadge')), findsNothing);

    await _openFilterSheet(tester);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Provider'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Aargee GPS (1)'), findsOneWidget);
    expect(find.text('HashTrace Tracker (1)'), findsOneWidget);
    expect(find.text('Transight GPS (1)'), findsOneWidget);
    expect(find.text('Bus (1)'), findsOneWidget);

    // Tapping a provider chip applies immediately — the fleet
    // behind the sheet filters at once.
    await tester.tap(find.text('Aargee GPS (1)'));
    await tester.pump();
    expect(_card('KL00XX0001'), findsOneWidget);
    expect(_card('KL00XX0002'), findsNothing);
    expect(_card('KL00XX0003'), findsNothing);
    // One active filter → the tune button carries a badge.
    expect(find.byKey(const Key('filterBadge')), findsOneWidget);

    // Clear all resets provider + category (status untouched) and
    // drops the badge; the whole fleet is back.
    await tester.tap(find.text('Clear all'));
    await tester.pump();
    expect(_card('KL00XX0001'), findsOneWidget);
    expect(_card('KL00XX0002'), findsOneWidget);
    expect(_card('KL00XX0003'), findsOneWidget);
    expect(find.byKey(const Key('filterBadge')), findsNothing);

    // Done closes the sheet — a plain pump first to process the
    // tap and start the dismiss animation, then 500ms to finish it.
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Filters'), findsNothing);
  });
}
