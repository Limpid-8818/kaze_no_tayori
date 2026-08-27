# SplashPortrait.imageset

iOS 竖屏启动素材。系统 LaunchScreen.storyboard 先显示同色静态底色，Scene 建立后由
`StartupSplashView` 根据初始方向选择本素材，并以 `scaleAspectFill` 铺满到 Flutter 首帧。
方向只在 Scene 建立时读取一次，启动页显示期间旋转不会换图。

- 来源：D:/Documents/Tencent Files/QQ Files/IMG_20260827_191926.png（1600x2848 水彩原画）
- 入库文件为 q90 JPEG 直转副本；splash_portrait.jpg 即完整原图内容。
- 更换素材时直接替换本目录 splash_portrait.jpg 并保持 Contents.json 文件名一致。

姊妹 set：../SplashLandscape.imageset（横版，源 IMG_20260827_192045.jpg 2304x1728）。
