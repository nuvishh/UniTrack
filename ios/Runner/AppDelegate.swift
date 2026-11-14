import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Runtime Google Maps API key (v1.5.0): the user types their own
    // key in Settings, so it cannot live in the AppDelegate at build
    // time. The Dart side sends the saved key over the `unitrack/maps`
    // channel before the first GoogleMap widget is built, and this
    // hands it to the Maps SDK. A changed key only takes effect after
    // an app restart — the SDK keeps the first key it saw.
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "unitrack-maps")
    let channel = FlutterMethodChannel(
      name: "unitrack/maps",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "applyApiKey" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let key = call.arguments as? String, !key.trimmingCharacters(in: .whitespaces).isEmpty else {
        result(
          FlutterError(
            code: "INVALID_KEY",
            message: "Empty Google Maps API key",
            details: nil
          )
        )
        return
      }
      GMSServices.provideAPIKey(key)
      result(true)
    }
  }
}
