import Flutter
import UIKit

/// ⚠️ **C'est ICI qu'arrive un fichier ouvert depuis l'extérieur, pas dans
/// l'`AppDelegate`.**
///
/// L'app adopte le cycle de vie par SCÈNES (`UIApplicationSceneManifest` +
/// `UISceneDelegateClassName` dans Info.plist — le gabarit iOS de Flutter le
/// pose depuis peu). Dès qu'une scène existe, UIKit livre les URL à
/// `scene(_:openURLContexts:)` et à `willConnectTo`, et n'appelle **jamais**
/// `application(_:open:options:)`. Un `AppDelegate` qui l'implémente a l'air
/// juste, compile, et ne se déclenche pas: « Ouvrir avec » lance l'app et ne
/// fait rien — exactement le symptôme observé.
///
/// Le tampon et le canal restent chez l'`AppDelegate` (voir `pendingOpen`): la
/// scène va et vient, lui pas, et c'est lui qui tient le canal du moteur.
class SceneDelegate: FlutterSceneDelegate {

  /// Démarrage à FROID causé par le fichier: l'URL arrive dans les options de
  /// connexion, pas par `openURLContexts`.
  override func scene(_ scene: UIScene,
                      willConnectTo session: UISceneSession,
                      options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    ingest(connectionOptions.urlContexts)
  }

  /// L'app tournait déjà.
  override func scene(_ scene: UIScene,
                      openURLContexts URLContexts: Set<UIOpenURLContext>) {
    // Les URL de FICHIER sont à nous; tout le reste (schémas des greffons,
    // retours OAuth) va à Flutter, qui les distribue.
    let files = URLContexts.filter { $0.url.isFileURL }
    let rest = URLContexts.subtracting(files)
    if !rest.isEmpty { super.scene(scene, openURLContexts: rest) }
    ingest(files)
  }

  private func ingest(_ contexts: Set<UIOpenURLContext>) {
    guard let app = UIApplication.shared.delegate as? AppDelegate else { return }
    for context in contexts where context.url.isFileURL {
      app.ingestOpenedFile(context.url)
    }
  }
}
