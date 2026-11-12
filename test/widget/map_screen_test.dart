import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unitrack/models/saved_vehicle.dart';
import 'package:unitrack/models/vehicle.dart';
import 'package:unitrack/models/vehicle_category.dart';
import 'package:unitrack/providers/storage_provider.dart';
import 'package:unitrack/providers/tracker_provider.dart';
import 'package:unitrack/screens/map_screen.dart';
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

class _FakeTracker extends TrackerNotifier {
  _FakeTracker(this.vehicles);

  final List<Vehicle> vehicles;

  @override
  TrackerState build() => TrackerState(vehicles: vehicles);
}

/// Serves a valid 1x1 PNG for every HTTP request, so the OSM tiles
/// load without touching the network.
class _FakeHttpOverrides extends HttpOverrides {
  static final Uint8List _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _FakeHttpClient();
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

const _bus = Vehicle(
  id: '860000000000001',
  displayName: 'KL00XX0001',
  providerKey: 'aargee',
  latitude: 12.0,
  longitude: 75.0,
  speedKmph: 40,
  ignition: true,
  status: VehicleStatus.live,
  category: VehicleCategory.bus,
);
const _car = Vehicle(
  id: '10001',
  displayName: 'KL00XX0002',
  providerKey: 'hashtrace',
  latitude: 12.01,
  longitude: 75.01,
  speedKmph: 0,
  ignition: true,
  status: VehicleStatus.live,
  category: VehicleCategory.car,
);

void main() {
  late HttpOverrides? oldOverrides;

  setUp(() {
    oldOverrides = HttpOverrides.current;
    HttpOverrides.global = _FakeHttpOverrides();
  });

  tearDown(() {
    HttpOverrides.global = oldOverrides;
  });

  testWidgets('map markers show the vehicle category icon',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(_FakeStorage()),
          trackerProvider.overrideWith(() => _FakeTracker([_bus, _car])),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const MapScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('2 live · 0 idle · 2 total'), findsOneWidget);
    // One marker per vehicle, each with its category icon.
    expect(find.byIcon(Icons.directions_bus), findsOneWidget);
    expect(find.byIcon(Icons.directions_car), findsOneWidget);
    expect(find.text('KL00XX0001'), findsOneWidget);
    expect(find.text('KL00XX0002'), findsOneWidget);

    // Tapping the bus marker opens the bottom sheet with its type.
    await tester.tap(find.byIcon(Icons.directions_bus));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Bus'), findsWidgets);
    expect(find.text('KL00XX0001'), findsWidgets);
  });
}
