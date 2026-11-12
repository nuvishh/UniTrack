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
import 'package:unitrack/screens/alerts_screen.dart';
import 'package:unitrack/screens/dashboard_screen.dart';
import 'package:unitrack/screens/home_screen.dart';
import 'package:unitrack/screens/reports_screen.dart';
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
        // All five tabs are present in the bottom nav (the matching
        // screen AppBar titles are built too — IndexedStack).
        expect(find.text('Dashboard'), findsWidgets);
        expect(find.text('Fleet'), findsWidgets);
        expect(find.text('Map'), findsWidgets);
        expect(find.text('Reports'), findsWidgets);
        expect(find.text('Alerts'), findsWidgets);
        // The Dashboard donut + empty state render.
        expect(find.text('Notifications'), findsOneWidget);
      });
    }
  });

  group('new screens smoke test — no overflow', () {
    for (final size in [const Size(360, 640), const Size(430, 932)]) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('DashboardScreen at $label', (tester) async {
        await _pumpAtSize(tester, size, const DashboardScreen());
        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('Moving'), findsOneWidget);
      });

      testWidgets('ReportsScreen at $label', (tester) async {
        await _pumpAtSize(tester, size, const ReportsScreen());
        expect(find.text('Reports'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Yesterday'), findsOneWidget);
      });

      testWidgets('AlertsScreen at $label', (tester) async {
        await _pumpAtSize(tester, size, const AlertsScreen());
        expect(find.text('Alerts'), findsOneWidget);
        expect(find.text('All (0)'), findsOneWidget);
        expect(find.text('Overspeed (0)'), findsOneWidget);
        expect(find.text('Geofence (0)'), findsOneWidget);
        // No SOS chip anywhere — no provider reports SOS.
        expect(find.text('SOS'), findsNothing);
      });
    }
  });
}
