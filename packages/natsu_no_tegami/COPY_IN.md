# 设计系统拷入契约

> 本包当前是**空壳**。真实的令牌与组件在上游独立仓库开发，成形后按本文整体拷入。
> **monorepo 内永不手改本包** —— 一切改动在上游做，再跑 `make sync-ds`。

## 上游

| 项 | 值 |
|---|---|
| 仓库 | `D:\CodeRepository\Flutter\natsu_no_tegami` |
| 分支 | `main`（无 remote） |
| 已拷入的源 commit | *（尚未拷入）* |

上游是一个纯展示层组件库 + 交互式画廊 App，零业务依赖（只有 flutter + cupertino_icons + flutter_lints）。

## 拷什么

| 源路径 | 目标 | 说明 |
|---|---|---|
| `lib/src/tokens/` | `lib/src/tokens/` | 7 个文件：Colors / Typography / Spacing / Radius+Borders+Motion / Shadows / Imperfection / barrel |
| `lib/src/components/` | `lib/src/components/` | Button / Card / Input / Quote / Seal / Tag / Kicker+SectionHeading+MetaLine |
| `lib/src/components/letters/` | 同上 | LetterPaper / PhotoCard / Postmark / StampPiece / DeskScene |
| `assets/fonts/` | `assets/fonts/` | 15 个字体：`info/` 6 个信息层 + `warm/` 9 个手写层 |
| `test/` | `test/` | 组件与令牌测试（828 行，含 WCAG 对比度与确定性种子断言） |
| `test/tool/export_design_tokens_test.dart` | 同上 | Dart → DTCG 单向导出器 |
| pubspec 的 `fonts:` 段 | `pubspec.yaml` | 整段搬来，13 个 family 声明 |

## 不拷什么

- `lib/main.dart` 与 `lib/showcase/` —— 那是画廊 App，不是库。若要保留可视验收，另建 `packages/natsu_no_tegami/example/`。
- `android/ ios/ web/ windows/ linux/ macos/` —— 六个平台目录全是未定制的 `flutter create` 脚手架（`com.example` 占位），本包是库不需要它们。
- `design_spec/` —— 那是指向仓库外的**符号链接**（`C:\Users\Yukai Shen\WorkBuddy\Spark from Yorushika`）。其中的 PRD / 需求分析 / 设计叙事已在本仓库 `docs/` 里，不要重复引入。
- `design_tokens/natsu-tokens-v2.json` —— 本仓库 `docs/natsu-tokens-v2.json` 已有同内容镜像。

## 拷完做什么

1. 删掉 `lib/natsu_no_tegami.dart` 里的占位说明，改为上游 barrel：
   ```dart
   export 'src/components/components.dart';
   export 'src/tokens/natsu_tokens.dart';
   ```
2. 删掉 App 侧的临时主题 `apps/app/lib/app/theme.dart` 里的 `KazeTempTheme`，改为用上游令牌构造 `ThemeData`。**`theme.dart` 是唯一允许 import 本包的地方。**
3. `cd apps/app && flutter pub get && flutter analyze && flutter test`
4. 在上表「已拷入的源 commit」记下源 commit hash。
5. 提交信息用 `chore: 拷入设计系统 <short-hash>`。

## 两个坑

**同名文件不同职责。** 上游有两个 `natsu_typography.dart`：
- `lib/src/tokens/natsu_typography.dart` —— 224 行，纯 TextStyle 常量
- `lib/src/components/natsu_typography.dart` —— 78 行，`NatsuKicker` / `NatsuSectionHeading` / `NatsuMetaLine` 组件

同步脚本**按目录整体拷贝、不做扁平化**，别把这两个合并。

**字体文件曾经损坏过。** 上游 git log 有一条 `fix: 修复损坏的 RobotoMono 字体文件导致的 web 加载崩溃`。拷入后先跑一次 `flutter run -d edge` 确认字体能加载。

## 时机建议

越晚拷入，App 里积累的临时主题适配就越多。建议**写信流做完后就先拷一次 tokens 层**（那层已稳定、已有 DTCG 导出），components 层等定稿。
