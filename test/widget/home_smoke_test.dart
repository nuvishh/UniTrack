import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unitrack/models/saved_vehicle.dart';
import 'package:unitrack/providers/storage_provider.dart';
import 'package:unitrack/screens/add_vehicle_screen.dart';
import 'package:unitrack/screens/fleet_list_screen.dart';
import 'package:unitrack/screens/home_screen.dart';
import 'package:unitrack/screens/map_screen.dart';
import 'package:unitrack/screens/settings_screen.dart';
import 'package:unitrack/services/secure_storage_service.dart';
import 'package:unitrack/theme/app_theme.dart';

/// In-memory stand-in for [SecureStorageService]: no storage, no
/// network. Mirrors the fake in test/providers/tracker_provider_test.dart.
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

/// Serves a valid 1x1 PNG for every HTTP request, so the map tiles
/// in MapScreen load without touching the network (and without the
/// image-error reports that would fail the test).
class _FakeHttpOverrides extends HttpOverrides {
  static final Uint8List _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
}

class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeRequest();

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _FakeResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeResponse implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => _FakeHttpOverrides._png.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(
      _FakeHttpOverrides._png,
    ).listen(onData, onError: onError, onDone: onDone);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpApp(WidgetTester tester, Widget child) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(_FakeStorage()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Pumps [child] at [size] and fails on any overflow or other
/// framework error reported during the pump.
Future<void> _pumpAtSize(
  WidgetTester tester,
  Size size,
  Widget child,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await _pumpApp(tester, child);
  await tester.pumpAndSettle(const Duration(seconds: 2));
  expect(tester.takeException(), isNull);
}

void main() {
  late HttpOverrides? oldOverrides;

  setUp(() {
    oldOverrides = HttpOverrides.current;
    HttpOverrides.global = _FakeHttpOverrides();
  });

  tearDown(() {
    HttpOverrides.global = oldOverrides;
  });

  group('HomeScreen smoke test — no overflow', () {
    for (final size in [const Size(360, 640), const Size(430, 932)]) {
      testWidgets('HomeScreen at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await _pumpAtSize(tester, size, const HomeScreen());
        // Exactly four tabs in the bottom nav (Fleet / Map / Add /
        // Settings) — Dashboard, Reports and Alerts are gone in v1.2.0.
        expect(find.text('Fleet'), findsWidgets);
        expect(find.text('Map'), findsWidgets);
        expect(find.text('Add'), findsWidgets);
        expect(find.text('Settings'), findsWidgets);
        expect(find.text('Dashboard'), findsNothing);
        expect(find.text('Reports'), findsNothing);
        expect(find.text('Alerts'), findsNothing);
        // The fleet empty state renders on the first tab.
        expect(find.text('No vehicles yet'), findsOneWidget);
        // No "+ Add vehicle" button on the Fleet tab any more
        // (v1.3.1) — the Add tab is the only entry point now.
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('Add vehicle'), findsNothing);
        // The Add tab still opens the wizard.
        await tester.tap(find.text('Add'));
        await tester.pump();
        expect(find.text('Add vehicle'), findsOneWidget);
        expect(
          find.text('Which GPS provider is this vehicle on?'),
          findsOneWidget,
        );
      });
    }
  });

  group('screens smoke test — no overflow', () {
    for (final size in [const Size(360, 640), const Size(430, 932)]) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('FleetListScreen at $label', (tester) async {
        await _pumpAtSize(tester, size, const FleetListScreen());
        expect(find.text('UniTrack'), findsOneWidget);
        expect(find.text('No vehicles yet'), findsOneWidget);
        // The empty-state button can sit below the fold on a short
        // screen (the state scrolls) — find it offstage.
        expect(
          find.text('Add your first vehicle', skipOffstage: false),
          findsOneWidget,
        );
      });

      testWidgets('MapScreen at $label', (tester) async {
        await _pumpAtSize(tester, size, const MapScreen());
        expect(find.text('Map'), findsOneWidget);
        expect(find.text('No vehicles on the map yet'), findsOneWidget);
      });

      testWidgets('AddVehicleScreen at $label', (tester) async {
        await _pumpAtSize(tester, size, const AddVehicleScreen());
        expect(find.text('Add vehicle'), findsOneWidget);
        expect(find.text('Provider'), findsWidgets);
        // Vehicle-type picker on the credentials step is reachable
        // from step 1 — the chips exist in the widget tree.
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Vehicle type'), findsOneWidget);
        expect(find.text('Bus'), findsOneWidget);
        expect(find.text('Car'), findsOneWidget);
        expect(find.text('Truck'), findsOneWidget);
        expect(find.text('Bike'), findsOneWidget);
        expect(find.text('Other'), findsOneWidget);
      });

      testWidgets('SettingsScreen at $label', (tester) async {
        await _pumpAtSize(tester, size, const SettingsScreen());
        expect(find.text('Settings'), findsOneWidget);
        // The Colour theme picker (v1.3.0) pushes Backup & restore
        // below the fold on a short screen — scroll it into view;
        // offscreen ListView children are not built.
        await tester.scrollUntilVisible(
          find.text('Backup & restore'),
          200,
        );
        expect(find.text('Backup & restore'), findsOneWidget);
        // The About card sits below the fold in a ListView — scroll
        // it into view; offscreen ListView children are not built.
        // Version-agnostic on purpose: the string changes every bump.
        await tester.scrollUntilVisible(
          find.textContaining(RegExp(r'Version \d+\.\d+\.\d+')),
          200,
        );
        expect(
          find.textContaining(RegExp(r'Version \d+\.\d+\.\d+')),
          findsOneWidget,
        );
        // No Alerts section any more — notifications don't arrive
        // on the user's phone, so the app dropped them in v1.2.0.
        expect(find.text('Alerts'), findsNothing);
        expect(find.text('Overspeed limit'), findsNothing);
      });
    }
  });
}
