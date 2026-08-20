import Flutter
import UIKit
import UserNotifications

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let response = connectionOptions.notificationResponse {
      (UIApplication.shared.delegate as? AppDelegate)?.recordNotificationResponse(response)
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}
