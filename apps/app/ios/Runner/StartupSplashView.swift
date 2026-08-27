import UIKit

/// Flutter 首帧前的原生启动图。
///
/// 系统 LaunchScreen 不能绑定自定义类；这里运行在应用 Scene 建立之后，
/// 可以按初始方向选择素材。FlutterViewController 会在首帧渲染后自动移除本视图。
final class StartupSplashView: UIView {
  private static let skyHorizon = UIColor(
    red: 250 / 255.0,
    green: 248 / 255.0,
    blue: 241 / 255.0,
    alpha: 1
  )

  init(isLandscape: Bool) {
    super.init(frame: .zero)
    backgroundColor = Self.skyHorizon

    let imageView = UIImageView(
      image: UIImage(named: isLandscape ? "SplashLandscape" : "SplashPortrait")
    )
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.contentMode = .scaleAspectFill
    imageView.clipsToBounds = true
    imageView.isUserInteractionEnabled = false
    addSubview(imageView)

    NSLayoutConstraint.activate([
      imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
      imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
      imageView.topAnchor.constraint(equalTo: topAnchor),
      imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }
}
