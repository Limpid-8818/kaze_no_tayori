# 风信 · 开发路线图 v1

> 由 `PRD.md` §6 优先级 + `API_CONTRACT.md` 契约推导。前后端两条线可并行，
> 在三个联调节点（J1–J3）汇合。改契约/改优先级时同步本文。
>
> 现状基线（2026-08-20）：骨架完备、契约冻结（openapi.json 已导出）、质量关卡全绿；
> 全部 endpoint 与 service 是带契约注释的 stub，**初始迁移与 .env 未生成**。
>
> 更新（2026-08-23）：后端 B0–B6 全部完成、B7 已接 weather/geo（`make check` 与 `make check-db` 全绿）；
> DB 测试已迁移到独立 `test_<name>` schema，与 dev schema 完全隔离。前端 F1 起未动。

---

## 0. 总原则

- **契约先行**：契约已冻结，前端不等后端。后端每完成一个里程碑，前端把 mock 换成真接口即可。
- **核心循环优先**：写→漂/掘→读→共鸣/回信→通知，任何时刻这条链路的完成度都高于周边功能。
- **降级路径同步做**：每个可降级模块实装时，同时验证它的关闭分支（不能只写开通路径）。
- P1 功能（标签、共鸣短句墙、导出图、运营控制台）只在 P0 全链路走通后才动。

---

## 1. 后端路线（services/api）

依赖链：`B0 迁移 → B1 认证 → B2 写信 → B3 收信 → B4 互动 → B5 me → B6 种子/验收`，B7 可插空。

### B0 · 地基（0.5 天）⚡ 全局阻塞项
- [x] 配 `.env`（云库连接串 + `DB_SCHEMA=dev_<name>` + `JWT_SECRET`）
- [x] `make revision` 生成初始迁移，人工审阅两处坑（空间索引重复 / CREATE EXTENSION 置顶）
- [x] `make migrate` 建表；`check_db.py` 通过
- **验收**：`GET /health/db` 返回 postgis_version 与自己的 schema

### B1 · 认证 + 静态目录（0.5 天）
- [x] `account_service.upsert_by_device`（ON CONFLICT 幂等）→ `POST /v1/auth/device`
- [x] `catalog`：themes / tags 列表（seed 先灌静态行，或此处直接查表）
- **验收**：curl 用 device_id 换到 JWT；`GET /v1/themes` 返回 natsu

### B2 · 写信链路（1 天）
- [x] `storage_service`：Pillow 压缩（长边 1600 / JPEG ~82）+ 本地落盘 → `POST /v1/uploads/images`
- [x] `moderation_service` 最小实现：**纯关键词表**。`FEATURE_MODERATION=true` + 未命中 → PUBLIC；关闭/失败 → PENDING（红线 8）
- [x] `letter_service.create_letter`：stay 时 lat/lon 必填校验、`ST_MakePoint`、`theme_id` + `theme_skin` 一次写入永久绑定
- [x] blocks 应用层校验：最少 1 块、最多 20 块、照片 ≤3 张（契约不建 DB CHECK）；tags 存 id 还是 name 待定（契约列说明为 id，示例为 name，实装前定夺）→ **已定夺：存 id，契约示例已同步**
- [x] `GET /v1/letters/{id}`（非 public 一律 404）
- **验收**：两种 mode 各建一封；stay 信能被 ST_DWithin 查到；rejected 不泄漏存在性
- ⚠️ 开发期让信能进 public 的唯一合规路径是 `FEATURE_MODERATION=true` + 空关键词表（通过→PUBLIC 是契约允许的）

### B3 · 收信双入口（1 天）
- [x] `drift_service.draw_next`：`ORDER BY random()` + 排除自己/已开封/冷却内送达（子查询 letter_reads）+ 副作用只写 served_at 去重（**收信≠已读**）
- [x] `letter_reads` 语义拆分：`read_at` → `served_at` + `opened_at`（迁移 3e7dce148beb）；`POST /v1/letters/{id}/read` 开信上报 = read_count 唯一自增点
- [x] `discover_service.discover_nearby`：ST_DWithin + GiST，按 created_at DESC（不按热度），过滤 viewer 已开封信
- [x] `@pytest.mark.db` 测试：已开封过滤、池空 404 drift_pool_empty、半径边界、弃信冷却后回池、幂等计数
- **验收**：同一 user 连抽不重复（冷却内）；丢弃未开封信冷却后可重抽；抽完自己发的信后池空报 404；开信计数恰好一次

### B4 · 互动与回信（1 天）
- [x] `resonate`：ON CONFLICT DO NOTHING 幂等，note 时 voice_count+1，只回计数
- [x] `reply_service.create_reply`：复用 create_letter + parent 预置 + 原信 reply_count+1 + owner 非空插 Notification（为空静默）
- [x] `GET /letters/{id}/replies` 公开回信列表；`report` 入库
- [x] 通知端点**提前实装**（原属 B5）：`GET /me/notifications`（JOIN 原信取地名）+ 已读标记；实现方式定为**前端拉取**（开页拉取 + 回前台拉 unread_only），不做推送
- **验收**：重复共鸣计数不变；回信后原信作者通知出现，纯过客信无通知不报错

### B5 · me 全家桶（0.5 天）
- [x] 我的信（LetterOwned，含 pending）/ 下架（taken_down，非硬删）
- [x] 抄本 add/remove/list（saved_count 增减）；~~通知列表 + 已读标记~~（已随 B4 提前实装）
- **验收**：LetterOwned 仅出现在 /v1/me/*（test_anonymity 持续绿）

### B6 · 种子与端到端（0.5 天）
- [x] `seed_letters.py` 实装：upsert themes/tags + 插种子信（drift/stay 都有、带 place_label/weather、无 owner、直接 public）
- [x] 种子信文案：初版 12 封（drift 8 / stay 4，国内坐标、简体中文地名）已定并灌入，文案可随运营迭代
- [x] PRD §11 双路径的 API 层版本走通（ASGI 测试覆盖：drift 抽取链 + discover 发掘链）
- [x] **验收**：`make seed` 后 drift 池 8 封可抽；厦门种子坐标 1km discover 掘到 stay 信（2026-08-23 实测）
- 附带完成：DB 测试隔离改造（tests/conftest.py）——每个 db 测试独立 `test_<name>` schema
  （create_all 建表 + 测试后 DROP CASCADE），不再写 dev schema；测试内清种子信带 `test_` 前缀守卫，
  dev 演示数据不受影响。发现并修复：早前测试清理曾误删 dev 种子信，已重灌。

### B7 · 可降级模块真实接入（P1，按余量插空）
- [x] weather（QWeather 等）—— 内存缓存（TTL 10min）+ geo 降级 + X-QW-Api-Key 鉴权，失败返回 None
- [x] 逆地理（高德）—— `GET /v1/geo/reverse`，内存缓存（TTL 1h）+ 隐私截断（省市区，直辖市保留区级），失败返回 None，由用户手填 place_label
- [ ] AI 润色/短诗（OpenAI 兼容接口）—— 失败抛 FeatureDisabled
- [ ] LLM 审核分类接入 moderation；S3/minio 存储（infra 已备）
- 每项接完必须重验关闭分支

**后端 P0 合计约 5 人日。**

---

## 2. 前端路线（apps/app）

依赖链：`F0 数据层 → F1 写信（最大）→ F2 收信 → F3 阅读器 → F4 回信/通知 → F5 我的`，F6 时机特殊，F7 是 P1。

### F0 · 数据层与认证引导（0.5 天）
- [x] `secure_store`：首启生成 device_id（UUIDv4）存安全存储
- [x] 启动引导：静默 `POST /v1/auth/device` 换 JWT（401 自动重绑一次）
- [x] `data/api` 按资源补 endpoint 封装（letters/drift/discover/me/ai/uploads）
- [x] 验证 ApiClient 对 **204 无 body 响应**的容错（postJson 现假定 JSON body）
- [x] 补模型：LetterOwned、NotificationPublic、ThemePublic、TagPublic（现在只有 LetterPublic 一族）
- **验收**：冷启动无感登录；HealthCard 仍绿；`make check-dart` 过

### F1 · 写信流（1.5–2 天，全 App 最复杂）
- [ ] `write_controller`（@riverpod）+ 分步流：blocks 图文交替编辑（文字/照片块）→ 主题（`theme_id`）+ 皮肤槽位（`theme_skin`：stamp/postmarkEmblem/decor/postcard）→ 音乐引用 → 落点 → **必选留/投**
- [ ] 图片：image_picker 选 → 压缩 → uploads → 拼 URL
- [ ] 落点：geolocator 定位；失败/拒绝 → 手填 place_label（温和降级，不弹红错）
- [ ] 客户端校验与文案：blocks 1–20 块、照片 ≤3 张、标签 1–3 个（与契约一致，无字数硬限）
- [ ] 草稿本地暂存（data/local），离开不丢
- [ ] 留/投二选一的 UI 必须是显式一步，不许有默认值悄悄带过（PRD 6.1 必选）
- **验收**：stay 与 drift 各写成一封；断网时草稿还在；AI 关闭时写信流纯手动可走通

### F2 · 收信双入口（1 天）
- [ ] drift：抽一封 → 全屏信纸（复用 F3 渲染）；池空展示叙事态「此刻还没有漂来的信」（不是错误弹窗）
- [ ] discover：定位 → 半径预设（Env.discoverRadiusM）→ 附近信列表（时间序）
- [ ] 定位权限被拒的降级路径（手输坐标或引导开启）
- **验收**：双入口并列可达；driftPoolEmpty 呈现为叙事状态

### F3 · 阅读器（1 天）
- [ ] 信纸渲染：`地点·时间·天气` + blocks 图文交替流 + 短诗（引用体）+ 音乐引用 + `theme_skin` 槽位皮肤 + 计数文案「已被 N 个陌生人接住」
- [ ] ✦ 共鸣按钮（幂等，本地即时反馈）、回信入口、收进抄本、举报
- [ ] 溯源：parent_letter_id 非空可跳原信（public 才可达，404 就 404）
- **验收**：PRD 6.3 展示项全齐；页面上不存在任何作者位

### F4 · 回信 + 通知（0.5–1 天）
- [ ] 回信复用写信流（router 已留 `?parent=`），入口文案「回以一封信」，写完同样选留/投
- [ ] notifications 列表 + 已读 + 点击跳公开回信；拉取策略：开通知页拉一次 + App 回前台静默拉 `unread_only=true`（不做定时轮询、不建推送基建——契约「P0 只做拉取」）
- **验收**：回信发布后，原信作者设备上出现告知并能读到回信

### F5 · 我的信 + 抄本（0.5 天）
- [ ] 我的信：LetterOwned 渲染 + 状态徽标（pending/public/…）+ 下架确认（非硬删）
- [ ] 抄本：收藏列表 + 移除
- **验收**：下架后读者侧 404，回信链不塌

### F6 · 设计系统拷入（0.5–1 天，**时机：F1 完成后立即**）
- [ ] 按 `packages/natsu_no_tegami/COPY_IN.md`：先拷 tokens 层（上游已稳定），替换 `KazeTempTheme`
- [ ] components / letters（LetterPaper·Postmark·StampPiece·DeskScene）定稿后拷入，直接用于 reader 与 write
- **验收**：`make sync-ds` + `make check-dart`；feature 代码零改动（token 纪律的回报点）

### F7 · 导出图片（P1，0.5 天）
- [ ] `RepaintBoundary` 把带皮肤的信渲染成图（含 blocks 全部内容/短诗/音乐/落点/计数，**不含作者信息**）→ 存相册

**前端 P0 合计约 5–6 人日。**

---

## 3. 联调节点与排期

| 节点 | 前置 | 内容 |
|---|---|---|
| J1 | B2 + F1 | 写信端到端：App 写 → 落库 → status 正确 |
| J2 | B3+B4 + F2–F4 | 双入口收信 + 共鸣 + 回信 + 通知 |
| J3 | B6 + 全部 | PRD §11 双设备双路径验收（埋信→发掘→共鸣→回信→通知；投递→收到→导出） |

### 单人顺序（推荐）
```
B0 → B1 → B2 → F0 → F1 →(J1)→ B3 → B4 → F2 → F3 →(J2)→ B5 → F4 → F5 → B6 →(J3)
→ F6 → B7/F7 按余量
```

### 双人并行
```
后端线：B0 → B1 → B2 → B3 → B4 → B5 → B6 → B7
前端线：  F0 → F1 → F2 → F3 → F4 → F5 → F6 → F7
              └──J1──┘    └────J2────┘      └─J3─┘
```

按 10 天赛期（2026-08-20 起）：D1 地基+认证 / D2–3 写信前后端 / D4 联调 J1 + 收信后端 / D5 收信前端 + 互动后端 / D6 阅读器 / D7 me 前后端 + J2 / D8 种子 + J3 / D9 设计系统 + P1 / D10 缓冲与打磨。

---

## 4. 风险与待决

| # | 项 | 影响 | 对策 |
|---|---|---|---|
| 1 | `.env` 未配置，云库连接串未落 | **阻塞 B0，即阻塞一切 DB 工作** | 最优先向用户要连接串 |
| 2 | ~~种子信文案待定~~（已解决：初版 12 封于 B6 灌入） | — | 后续按运营反馈迭代文案即可 |
| 3 | FEATURE_MODERATION 关闭时信停在 pending，演示时「信发不出去」 | demo 体验 | 开发期 `FEATURE_MODERATION=true` + 空关键词表；LLM 审核接入后再收紧 |
| 4 | ApiClient 未验证 204 空 body | F0 一并处理 | postJson 对空响应返回 `{}` |
| 5 | cursor 分页未实现（next_cursor 恒 null） | demo 量级无影响 | 契约已留字段，不额外投入 |
| 6 | 共享库多人同时 `make revision` | 迁移链分叉 | 改 schema 前 `git pull`（CLAUDE.md §6 已立规） |
| 7 | 迁移文件硬编码 `schema="dev_limpid"` | 其他开发者/CI 跑 `make migrate` 会把表建进 dev_limpid；db 测试已绕行 create_all，模型↔迁移的漂移不被测试捕获 | 待办：迁移去 schema 化（依赖 search_path）或按开发者重生成初始迁移；做 CI 前必须解决 |

---

## 5. 每个里程碑的完成定义

1. `make check`（后端含 `not db` 测试 / 前端 analyze + test）全绿
2. 涉及 endpoint 的，`make openapi` 后 git diff 无契约漂移
3. 可降级模块同时验证开启与关闭两条路径
4. 匿名守卫（test_anonymity / widget_test）持续绿——红了先怀疑自己的 schema，不是测试
