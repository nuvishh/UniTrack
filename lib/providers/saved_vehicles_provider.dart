import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/saved_vehicle.dart';
import 'storage_provider.dart';

/// The vehicles the user added, as stored in shared_preferences
/// (non-secret fields only — secrets live in secure storage).
///
/// A [FutureProvider] because loading is async and only the Settings
/// screen needs this list. Refresh it with
/// `ref.invalidate(savedVehiclesProvider)` after adding or deleting
/// a vehicle.
final savedVehiclesProvider = FutureProvider<List<SavedVehicle>>((ref) async {
  return ref.read(secureStorageServiceProvider).loadVehicles();
});
