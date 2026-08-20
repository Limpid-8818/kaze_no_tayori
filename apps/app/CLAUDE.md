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
- **`natsu_no_tegami` 只许被 `lib/app/theme.dart` import。**

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
- applicationId 是 `fun.kazenotayori`（`flutter create` 默认会拼成 `fun.kazenotayori.kazenotayori`，已手工去重）。

## 提交前

`make check-dart`（dart format + flutter analyze + flutter test）。
