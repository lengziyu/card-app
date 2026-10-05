import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var apnsToken: String?
  private var initialRoute: String?
  private var pushChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    if let payload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      initialRoute = route(from: payload)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "cardfi/apns",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "App delegate is unavailable.", details: nil))
        return
      }
      switch call.method {
      case "requestPermission":
        self.requestNotificationPermission(result: result)
      case "token":
        result(self.apnsToken)
      case "initialRoute":
        result(self.initialRoute)
        self.initialRoute = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    pushChannel = channel

    let notificationSettingsChannel = FlutterMethodChannel(
      name: "cardfi/notifications",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    notificationSettingsChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "authorizationStatus":
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          let value: String
          switch settings.authorizationStatus {
          case .notDetermined:
            value = "notDetermined"
          case .authorized:
            value = "authorized"
          case .denied:
            value = "denied"
          case .provisional, .ephemeral:
            value = "provisional"
          @unknown default:
            value = "unavailable"
          }
          DispatchQueue.main.async { result(value) }
        }
      case "openSettings":
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
          result(opened)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    apnsToken = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    apnsToken = nil
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .badge, .sound])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let route = route(from: response.notification.request.content.userInfo) {
      pushChannel?.invokeMethod("notificationOpened", arguments: route)
      if pushChannel == nil {
        initialRoute = route
      }
    }
    completionHandler()
  }

  func recordNotificationResponse(_ response: UNNotificationResponse) {
    if let route = route(from: response.notification.request.content.userInfo) {
      initialRoute = route
    }
  }

  private func requestNotificationPermission(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
      granted, _ in
      DispatchQueue.main.async {
        if granted {
          UIApplication.shared.registerForRemoteNotifications()
        }
        result(granted)
      }
    }
  }

  private func route(from payload: [AnyHashable: Any]) -> String? {
    guard let route = payload["route"] as? String,
          route.hasPrefix("/"),
          !route.hasPrefix("//") else {
      return nil
    }
    return route
  }
}
