import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Tests must never hit the network for fonts: google_fonts would
/// otherwise fetch Poppins / JetBrains Mono from Google Fonts at
/// runtime. With fetching disabled the text theme falls back to the
/// default font in tests, which is all a widget test needs.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
