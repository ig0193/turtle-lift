import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications: the app delegate forwards notification
    // centre callbacks to the plugin, which is how a reminder tap reaches Dart,
    // both while running and when the tap launched the app (KTD17). Set before
    // launch finishes, so a launching tap is not missed under the scene
    // lifecycle, where launchOptions no longer carries it.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// The Live Activity and home-screen widget bridge (ADR 0008).
  static var glance: GlanceChannel?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GlanceChannel") {
      AppDelegate.glance = GlanceChannel(messenger: registrar.messenger())
    }
    // "Open Settings" under a notifications-off note (ADR 0014): the app's own
    // page in iOS Settings, where its notification switch lives.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SystemChannel") {
      let channel = FlutterMethodChannel(
        name: "dev.indresh.turtleLift/system", binaryMessenger: registrar.messenger())
      AppDelegate.system = channel
      channel.setMethodCallHandler { call, result in
        guard call.method == "openSettings",
          let url = URL(string: UIApplication.openSettingsURLString)
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        UIApplication.shared.open(url) { opened in result(opened) }
      }
    }
  }

  /// Kept alive for the life of the engine; see `didInitializeImplicitFlutterEngine`.
  static var system: FlutterMethodChannel?
}
