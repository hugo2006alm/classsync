import Flutter
import UIKit
import UserNotifications
#if CLASSSYNC_WIDGETS
import WidgetKit
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    #if CLASSSYNC_WIDGETS
    let channel = FlutterMethodChannel(
      name: "classsync/widget",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "save" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let slots = call.arguments as? [[String: Any]],
            slots.count <= 120,
            let container = FileManager.default.containerURL(
              forSecurityApplicationGroupIdentifier: "group.app.classsync.classsync"
            ) else {
        result(FlutterError(code: "widget_unavailable", message: nil, details: nil))
        return
      }
      do {
        let cache: [String: Any] = [
          "savedAt": Int64(Date().timeIntervalSince1970 * 1000),
          "slots": slots,
        ]
        let data = try JSONSerialization.data(withJSONObject: cache)
        guard data.count <= 128_000 else {
          result(FlutterError(code: "widget_cache_size", message: nil, details: nil))
          return
        }
        try data.write(
          to: container.appendingPathComponent("timetable.json"),
          options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
        WidgetCenter.shared.reloadTimelines(ofKind: "ClassSyncTimetable")
        result(nil)
      } catch {
        result(FlutterError(code: "widget_cache_write", message: nil, details: nil))
      }
    }
    #endif
  }
}
