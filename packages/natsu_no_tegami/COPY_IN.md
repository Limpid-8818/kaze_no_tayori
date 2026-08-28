# 设计系统拷入契约

> 本包是上游设计系统在 monorepo 中的同步副本，按本文白名单整体拷入。
> **monorepo 内永不手改本包** —— 一切改动在上游做，再跑 `make sync-ds`。

> 当前例外（2026-08-25）：本仓库已先修复 `NatsuTypography` 的 Flutter package 字体命名空间，并同步更新测试；该修复必须回灌上游后再执行下一次同步。`sync_design_system.sh` 已加前置守卫，旧上游不会覆盖当前正确版本。

## 待上游化清单（app 侧暂放组件）

- `apps/app/lib/app/widgets/letter_summary_card.dart`（2026-08-27，F4；F6 补 `statusLabel`/`onLongPress`）——信件摘要卡：俳句三行衬线排版（quoteSerif）+ 无诗回退手写预览 + meta 行「距离/地点 · 时间」+ 状态徽标（NatsuTag sm 纯文字，不启用语义点——dot 配色按配给制只归场景/情绪/旅行）。跨 feature 复用（发掘/我的信/抄本），上游化时建议落位 `lib/src/components/letters/`，参数保持纯字符串。
- `apps/app/lib/app/widgets/kaze_paper_stack.dart`（2026-08-28，信纸↔封筒切换）——纸叠切换台：AnimatedSwitcher（「新纸落下落定、旧纸下沉微缩淡出」的叠放顺序过渡）+ 外层 AnimatedSize 把新旧纸高矮差的两次尺寸突变插值成连续收放，锚默认 topCenter 保证换纸全程纸不挪位（long 320ms + driftEasing；上游化时 KazeMotion → NatsuMotion 直连）。跨 feature 复用（写信/读信），上游化时建议落位 `lib/src/components/`。
- `apps/app/lib/app/widgets/kaze_view_toggle.dart`（2026-08-28，信纸↔封筒切换）——视图切换文字胶囊（暖白纸底 + 发丝线 + Stadium 全圆角，图标随目标视图互换）。跨 feature 复用（写信/读信），上游化时建议落位 `lib/src/components/`。
- `apps/app/lib/app/widgets/kaze_pill_action.dart`（2026-08-28，读信页「看原信」入口）——胶囊动作钮：kaze_view_toggle 的外观母版（同款暖白纸底 + 发丝线 + Stadium，16px 图标 + labelSmall），无状态翻转的纯跳转/触发入口。跨 feature 复用，上游化时建议落位 `lib/src/components/` 并让 kaze_view_toggle 一并收编。

## 上游

| 项 | 值 |
|---|---|
| 仓库 | `D:\CodeRepository\Flutter\natsu_no_tegami` |
| 分支 | `main`（无 remote） |
| 已拷入的源 commit | `6bf5204` |

上游是一个纯展示层组件库 + 交互式画廊 App，零业务依赖（只有 flutter + cupertino_icons + flutter_lints）。

## 拷什么

| 源路径 | 目标 | 说明 |
|---|---|---|
| `lib/src/tokens/` | `lib/src/tokens/` | 9 个文件：Colors / Typography / Spacing / Radius+Borders+Motion / Shadows / Imperfection / PhotoMood / Weather / barrel |
| `lib/src/components/` | `lib/src/components/` | 18 个组件（含 resonance / toast / slider 等）+ barrel |
| `lib/src/components/letters/` | 同上 | 17 个文件：LetterPaper / PhotoCard / LetterBlock / LetterExport / LetterReading / DeskScene / StampPiece / skins 等 |
| `assets/fonts/` | `assets/fonts/` | 15 个字体：`info/` 6 个信息层 + `warm/` 9 个手写层 |
| `test/` | `test/` | 14 个测试文件（含 WCAG 对比度、deterministic seed 断言、DTCG 导出器） |
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
4. 提交信息用 `chore: 拷入设计系统 <short-hash>`。

## 两个坑

**同名文件不同职责。** 上游有两个 `natsu_typography.dart`：
- `lib/src/tokens/natsu_typography.dart` —— 224 行，纯 TextStyle 常量
- `lib/src/components/natsu_typography.dart` —— 78 行，`NatsuKicker` / `NatsuSectionHeading` / `NatsuMetaLine` 组件

同步脚本**按目录整体拷贝、不做扁平化**，别把这两个合并。

**字体文件曾经损坏过。** 上游 git log 有一条 `fix: 修复损坏的 RobotoMono 字体文件导致的 web 加载崩溃`。拷入后先跑一次 `flutter run -d edge` 确认字体能加载。

**依赖包字体必须带 package 命名空间。** Flutter 会把本包声明的 family 注册成 `packages/natsu_no_tegami/<family>`。`NatsuTypography` 中所有 `TextStyle` 必须传 `package: NatsuFontFamilies.packageName`；否则文件虽然进入产物，运行时仍会静默回落到系统字体。同步脚本会在拷贝前检查这一条件并拒绝旧上游，避免覆盖回退。

## 时机建议

越晚拷入，App 里积累的临时主题适配就越多。建议**写信流做完后就先拷一次 tokens 层**（那层已稳定、已有 DTCG 导出），components 层等定稿。
