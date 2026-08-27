import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard
      let windowScene = scene as? UIWindowScene,
      let flutterViewController = window?.rootViewController as? FlutterViewController
    else {
      return
    }

    let orientation = windowScene.interfaceOrientation
    let isLandscape = orientation == .unknown
      ? windowScene.coordinateSpace.bounds.width >= windowScene.coordinateSpace.bounds.height
      : orientation.isLandscape

    // 只在冷启动建 Scene 时确定一次；启动页显示期间旋转不切换素材。
    flutterViewController.splashScreenView = StartupSplashView(
      isLandscape: isLandscape
    )
  }
}
