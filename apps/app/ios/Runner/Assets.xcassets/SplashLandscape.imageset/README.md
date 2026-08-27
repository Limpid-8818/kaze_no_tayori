# SplashLandscape.imageset

iOS 启动屏横版素材（2304x1728 = 4:3，iPad 横屏零裁切）。

- 来源：D:/Documents/Tencent Files/QQ Files/IMG_20260827_192045.jpg（水彩原画横构图）
- 入库文件为 q90 JPEG 直转副本；splash_landscape.jpg 即完整原图内容。

姊妹 set：../SplashPortrait.imageset（竖屏）。Scene 建立后由 `StartupSplashView`
根据初始方向选择素材，并以 `scaleAspectFill` 铺满到 Flutter 首帧；该判断直接使用
`UIWindowScene.interfaceOrientation`，不依赖 Size Class，因此同样覆盖 iPad 横屏。
