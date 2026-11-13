import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unitrack/models/saved_vehicle.dart';
import 'package:unitrack/providers/storage_provider.dart';
import 'package:unitrack/screens/add_vehicle_screen.dart';
import 'package:unitrack/services/secure_storage_service.dart';
import 'package:unitrack/theme/app_theme.dart';

/// In-memory stand-in for [SecureStorageService]: no storage, no
/// network.
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

Future<void> _pumpWizard(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(_FakeStorage()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const AddVehicleScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('Add vehicle Continue button (v1.3.1)', () {
    for (final size in [const Size(360, 640), const Size(430, 932)]) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('Continue is full-width with a trailing arrow at $label',
          (tester) async {
        await _pumpWizard(tester, size);

        // Step 1 (provider): one full-width Continue, trailing arrow.
        final continueButton =
            find.widgetWithText(FilledButton, 'Continue');
        expect(continueButton, findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
        expect(
          tester.getSize(continueButton).width,
          size.width - 32,
        );
        expect(
          tester.getSize(continueButton).height,
          greaterThanOrEqualTo(52),
        );
        expect(tester.takeException(), isNull);

        // Step 2 (details): Back + Continue are stacked full-width
        // buttons, Continue below Back and closest to the bottom.
        await tester.tap(find.text('Continue'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.text('Enter Aargee GPS credentials'),
          findsOneWidget,
        );
        final backButton = find.widgetWithText(OutlinedButton, 'Back');
        final continueButton2 =
            find.widgetWithText(FilledButton, 'Continue');
        expect(backButton, findsOneWidget);
        expect(continueButton2, findsOneWidget);
        expect(tester.getSize(backButton).width, size.width - 32);
        expect(tester.getSize(continueButton2).width, size.width - 32);
        expect(
          tester.getTopLeft(continueButton2).dy,
          greaterThan(tester.getTopLeft(backButton).dy),
        );
        expect(tester.takeException(), isNull);

        // Back still works — it returns to the provider step.
        await tester.tap(find.text('Back'));
        await tester.pump();
        expect(
          find.text('Which GPS provider is this vehicle on?'),
          findsOneWidget,
        );
      });
    }
  });
}
