import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// A tap on the Live Activity or the home-screen widget arrives as
  /// `turtlelift://workout`. A running app is sent to the Workout tab; a cold
  /// launch opens there anyway, because Workout is the first tab (ADR 0008).
  ///
  /// Any other URL goes on to Flutter as before (deep linking itself is off:
  /// `FlutterDeepLinkingEnabled` = NO in Info.plist).
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if URLContexts.contains(where: { $0.url.scheme == GlanceStore.openWorkoutURL.scheme }) {
      AppDelegate.glance?.openWorkout()
      return
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
