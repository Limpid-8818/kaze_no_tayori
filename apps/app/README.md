# 风信 Flutter 客户端

客户端采用 feature-first 结构。业务页面开始开发前，先复用已有应用级基础设施：

- 普通页面使用 `lib/app/widgets/kaze_scaffold.dart`，首页和信件专用画布除外。
- 定位使用 `locationControllerProvider`，不要在 feature 内直接调用 `Geolocator`。
- 权限使用 `permissionControllerProvider`，系统权限弹窗只能由用户明确动作触发。
- 网络请求只经过 `lib/data/api/api_client.dart` 与各 endpoint API。
- 设计系统只从 `lib/app/theme.dart` 映射到 App 主题；同步包用仓库根目录的 `make sync-ds`。

从仓库根目录运行：

```bash
make app          # Web
make app-android  # Android 真机/模拟器
make app-ios IOS_DEVICE=<flutter-device-id>  # iPhone 真机/模拟器
make check-dart   # format + analyze + test
```

Android/iPhone 真机访问本机后端时，用 `API_BASE_URL` 指向开发机局域网 IP，不能使用 `localhost`；iOS 模拟器可以访问 Mac 的 `127.0.0.1`。
Android 明文 HTTP 仅在 debug 构建放行；iOS 首次访问局域网后端会请求本地网络权限。公网和 release 环境必须使用 HTTPS。Web 定位只能运行在 HTTPS 或 localhost 的 secure context。
完整模块边界与开发顺序见 `docs/ARCHITECTURE.md` 和 `docs/ROADMAP.md`。
