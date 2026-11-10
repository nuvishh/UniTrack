import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/secure_storage_service.dart';

/// The app's storage service (secrets in secure storage, the vehicle
/// list + refresh interval in shared_preferences).
///
/// A plain [Provider] so tests can override it with an in-memory fake.
final secureStorageServiceProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);
