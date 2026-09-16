import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url,
       let appDelegate = UIApplication.shared.delegate as? AppDelegate,
       appDelegate.openPlayer(from: url) {
      return
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
