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
    let appearance = FlutterMethodChannel(
      name: "classsync/appearance",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    appearance.setMethodCallHandler { call, result in
      switch call.method {
      case "read":
        result(UserDefaults.standard.string(forKey: "classsyncAppearance"))
      case "write":
        guard let value = call.arguments as? String,
              ["system", "light", "dark"].contains(value) else {
          result(FlutterError(code: "invalid_appearance", message: nil, details: nil))
          return
        }
        UserDefaults.standard.set(value, forKey: "classsyncAppearance")
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
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
      guard let slots = call.arguments as? [[String: Any]], slots.count <= 120 else {
        result(FlutterError(code: "widget_cache_invalid", message: nil, details: nil))
        return
      }
      do {
        #if CLASSSYNC_WIDGET_GROUP_TEST
        try TimetableWidgetStorage.write(slots: slots, demoIfEmpty: true)
        #else
        try TimetableWidgetStorage.write(slots: slots)
        #endif
        WidgetCenter.shared.reloadTimelines(ofKind: "ClassSyncTimetable")
        result(nil)
      } catch TimetableWidgetStorage.Failure.containerUnavailable {
        result(FlutterError(code: "widget_container_unavailable", message: nil, details: nil))
      } catch {
        result(FlutterError(code: "widget_cache_write", message: nil, details: nil))
      }
    }
    #endif
  }
}
