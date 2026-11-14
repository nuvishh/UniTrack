package com.nuvish.unitrack

import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Applies the user-entered Google Maps API key at runtime (v1.5.0).
///
/// google_maps_flutter normally reads the key from the manifest
/// meta-data at build time, which cannot hold a key the user types in
/// Settings. Instead the Dart side sends the saved key over the
/// `unitrack/maps` channel before the first GoogleMap widget is
/// built, and this writes it into the ApplicationInfo meta-data
/// Bundle (`com.google.android.geo.API_KEY`) — the same place the
/// Maps SDK reads it from when the first map is created. The
/// PackageManager caches the ApplicationInfo per process, so the
/// write sticks for the rest of the app session.
///
/// A changed key only takes effect after an app restart: the SDK
/// keeps the first key it saw.
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "unitrack/maps",
        ).setMethodCallHandler { call, result ->
            if (call.method != "applyApiKey") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val key = call.arguments as? String
            if (key.isNullOrBlank()) {
                result.error("INVALID_KEY", "Empty Google Maps API key", null)
                return@setMethodCallHandler
            }
            try {
                val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    packageManager.getApplicationInfo(
                        packageName,
                        PackageManager.ApplicationInfoFlags.of(
                            PackageManager.GET_META_DATA.toLong(),
                        ),
                    )
                } else {
                    @Suppress("DEPRECATION")
                    packageManager.getApplicationInfo(
                        packageName,
                        PackageManager.GET_META_DATA,
                    )
                }
                if (appInfo.metaData == null) appInfo.metaData = Bundle()
                appInfo.metaData.putString(
                    "com.google.android.geo.API_KEY",
                    key,
                )
                result.success(true)
            } catch (e: Exception) {
                result.error("APPLY_FAILED", e.message, null)
            }
        }
    }
}
