import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack/models/saved_vehicle.dart';
import 'package:unitrack/providers/storage_provider.dart';
import 'package:unitrack/providers/tracker_provider.dart';
import 'package:unitrack/services/secure_storage_service.dart';

/// In-memory stand-in for [SecureStorageService]: no SharedPreferences,
/// no secure storage, no network — the notifier's logic is tested,
/// not the storage. The refresh interval is persisted in memory, like
/// the real service persists it in SharedPreferences.
class FakeStorage extends SecureStorageService {
  FakeStorage({
    this.vehicles = const [],
    this._interval = const Duration(seconds: 60),
  });

  final List<SavedVehicle> vehicles;
  Duration _interval;

  @override
  Future<List<SavedVehicle>> loadVehicles() async => vehicles;

  @override
  Future<Duration> getRefreshInterval() async => _interval;

  @override
  Future<void> setRefreshInterval(Duration interval) async {
    _interval = interval;
  }

  @override
  Future<String?> readSecret(String vehicleId) async => null;
}

ProviderContainer _containerWith(FakeStorage storage) {
  final container = ProviderContainer(
    overrides: [secureStorageServiceProvider.overrideWithValue(storage)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('starts empty, not refreshing, no error', () {
    final container = _containerWith(FakeStorage());

    final state = container.read(trackerProvider);

    expect(state.vehicles, isEmpty);
    expect(state.isRefreshing, isFalse);
    expect(state.lastError, isNull);
    expect(state.refreshInterval, const Duration(seconds: 60));
  });

  test('setRefreshInterval updates the state', () async {
    final container = _containerWith(FakeStorage());
    final notifier = container.read(trackerProvider.notifier);

    // Let the background first load finish before changing the interval.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await notifier.setRefreshInterval(const Duration(minutes: 2));

    expect(
      container.read(trackerProvider).refreshInterval,
      const Duration(minutes: 2),
    );
  });

  test('an account with no saved credentials reports an error', () async {
    final container = _containerWith(
      FakeStorage(
        vehicles: const [
          SavedVehicle(
            id: 'test-1',
            providerKey: 'aargee',
            deviceId: '123456789012345',
          ),
        ],
      ),
    );
    final notifier = container.read(trackerProvider.notifier);

    await notifier.refreshAll();
    // The background first load may still be finishing.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final state = container.read(trackerProvider);
    expect(state.vehicles, isEmpty);
    expect(state.lastError, isNotNull);
    expect(state.lastError, contains('no credentials'));
  });
}
