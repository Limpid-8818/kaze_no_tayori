import UIKit

/// 启动屏控制器：LaunchScreen.storyboard 以 customClass 挂载，全屏铺水彩启动图。
/// 按当前视图宽高比在竖版/横版素材间切换（Assets.xcassets 的 SplashPortrait /
/// SplashLandscape imageset，由 scripts/make_splash_assets.py 从两幅原图生成）。
final class SplashScreenController: UIViewController {
    /// NatsuColors.skyHorizon (#FAF8F1)：素材比例不匹配时的兜底色，
    /// 与首页 scaffoldBackgroundColor 同值，保证 splash→首帧零跳变。
    private static let skyHorizon = UIColor(
        red: 250 / 255.0, green: 248 / 255.0, blue: 241 / 255.0, alpha: 1
    )

    private let imageView = UIImageView()
    private var showingLandscape: Bool?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Self.skyHorizon
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        updateImageIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateImageIfNeeded()
    }

    override func viewWillTransition(
        to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in self.updateImageIfNeeded() })
    }

    private func updateImageIfNeeded() {
        guard view.bounds.width > 0 else { return }
        let landscape = view.bounds.width >= view.bounds.height
        guard landscape != showingLandscape else { return }
        showingLandscape = landscape
        imageView.image = UIImage(named: landscape ? "SplashLandscape" : "SplashPortrait")
    }
}
