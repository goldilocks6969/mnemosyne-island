import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Save a Review launch before Flutter starts processing its first frame.
        for context in connectionOptions.urlContexts {
            ReviewRouter.shared.receive(context.url)
        }
        super.scene(scene, willConnectTo: session, options: connectionOptions)
    }

    override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            ReviewRouter.shared.receive(context.url)
        }
        super.scene(scene, openURLContexts: URLContexts)
    }
}
