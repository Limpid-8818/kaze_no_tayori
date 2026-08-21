# 前端局部规则（apps/app）

> 全局红线见仓库根 `CLAUDE.md` §2。接口契约见 `docs/API_CONTRACT.md`。

## 结构（feature-first）

```
lib/app/       router / theme / home_screen / widgets（跨 feature 复用的组件）
lib/core/      env / result（ApiFailure）
lib/data/      api（dio + 各 endpoint）/ models / local（安全存储、草稿）
lib/features/  write drift discover reader reply my_letters scripbook notifications settings
```

每个 feature 三件套：`*_screen.dart` + `*_controller.dart`（`@riverpod` Notifier）+ `widgets/`。

- **feature 之间不得互相 import。** 共享的上提到 `core/` 或 `data/`，视觉组件放 `lib/app/widgets/`。
- **网络只经 `data/api/api_client.dart`**，不要在 feature 里 new Dio。
- **禁止字面量颜色/字号/间距**，一律 `Theme.of(context)`。这样上游设计系统拷入后不用改 feature。
- **`natsu_no_tegami` 的令牌层（tokens/）只许被 `lib/app/theme.dart` import。**
  feature 代码走 `Theme.of(context)`，不写字面量颜色/字号/间距。
- **`natsu_no_tegami` 的组件层（components/letters/、components/）可由 feature 直接 import。**
  信件组件（LetterPaper / PhotoCard / LetterBlock 等）和通用组件（NatsuButton / NatsuCard 等）
  是渲染层的二等公民，不需要经过 theme.dart 中转。

## 代码生成

改了 `@riverpod` / `@JsonSerializable` 注解后必须 `make gen`（开发期可 `make gen-watch`）。
生成物 `*.g.dart` 不入库。

**没有 freezed**：与 riverpod_generator / flutter_riverpod 的 analyzer 版本无解冲突，
见 `pubspec.yaml` 里的详细说明。模型用 `@JsonSerializable` + final 字段手写。

## 降级要温和

`ApiFailure.isDegradable` 为真时（`feature_disabled` / `service_unavailable`）
界面应退到可用状态而非弹红色报错：AI 关了就纯手动写信，天气取不到就不显示天气。
`driftPoolEmpty` 是叙事状态——「此刻还没有漂来的信」，不是错误。

## 平台

- 只有 android + web。Web 用 `make app`（走 `-d edge`，**本机无 Chrome**）。
- 真机调试：`make app-android API_BASE_URL=http://<局域网IP>:8000`，不能用 localhost。
- applicationId / namespace 是 `com.aisquare.kazenotayori`。早期用过 `fun.kazenotayori`，但 `fun` 是
  Kotlin 保留字、包声明只能写反引号畸形语法，2026-08-20 已整体迁移，别改回去。
- Android 构建（2026-08-20 实测）：`permission_handler` 钉在 **12.x**、`flutter_secure_storage` 的 compileSdk 靠
  `android/build.gradle.kts` 的钳制压到 36。原因：它们的 14/11+ 版本要 compileSdk 37，而 API 37 平台包在 SDK
  仓库里只有 `android-37.0`（坏元数据），AGP 按 hash `android-37` 永远找不到；14.0.0 源码还真实调用了 API 37
  独有符号，无法用钳制绕过。升级前先确认上游已适配。构建时 `requires Android SDK version 37` 的 Warning 可无视。

## 提交前

`make check-dart`（dart format + flutter analyze + flutter test）。
