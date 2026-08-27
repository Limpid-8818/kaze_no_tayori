# 风信 · 开发路线图 v1

> 由 `PRD.md` §6 优先级 + `API_CONTRACT.md` 契约推导。前后端两条线可并行，
> 在三个联调节点（J1–J3）汇合。改契约/改优先级时同步本文。
>
> 现状基线（2026-08-20）：骨架完备、契约冻结（openapi.json 已导出）、质量关卡全绿；
> 全部 endpoint 与 service 是带契约注释的 stub，**初始迁移与 .env 未生成**。
>
> 更新（2026-08-25）：后端 B0–B7 已完成；前端数据层 F0 与应用基础设施 F1 已完成。
> F1 补齐了统一页面骨架、权限/定位全局控制器、生命周期入口、Android 权限清单和字体命名空间；
> 后续 feature 页面不得再各自实现这些能力。
>
> 更新（2026-08-27）：F2 写信闭环与 F3 阅读器已完成（均过真实接口 E2E）。F3 留下集中
> mapper（`letter_view.dart`）与 `INITIAL_ROUTE` 调试直通车，F4 收信双入口直接复用。
>
> 更新（2026-08-27）：F4 收信双入口与 F5 回信/通知已完成。F5 留下 app 级
> `UnreadCountController`（抽屉角标唯一所有者，开页/回前台经 AppLifecycle 拉取），
> F6 我的信直接复用 MeApi；J2 联调节点达成。
>
> 更新（2026-08-27）：F6 我的信已完成——信件操作统一为长按弹底部交互区
> （`LetterSummaryCard.onLongPress` 能力全列表可用，本阶段只在 /me/letters 接线），
> `core/letter_preview.dart` 为摘要抽取共享口径。前端 P0 全部完成，仅剩 J3-P0
> 双设备核心验收。
>
> 更新（2026-08-27）：F7 抄本已完成——收藏列表 + 移出（两段式确认：读过的信
> 不会再漂流回来）。入口在读信页「⋯」菜单「记入抄本」（后端幂等、菜单项恒可点），
> 列表页复用 MyLetters 四相骨架与 letter_preview 口径；mock 补三条 scripbook 路由。

---

## 0. 总原则

- **契约先行**：契约已冻结，前端不等后端。后端每完成一个里程碑，前端把 mock 换成真接口即可。
- **核心循环优先**：写→漂/掘→读→共鸣/回信→通知，任何时刻这条链路的完成度都高于周边功能。
- **降级路径同步做**：每个可降级模块实装时，同时验证它的关闭分支（不能只写开通路径）。
- P1 功能（音乐、标签、自选皮肤、抄本、导出图、共鸣短句墙、运营控制台）只在 P0 全链路走通后才动。

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
- [x] `storage_service`：Pillow 压缩（长边 1600 / JPEG ~82）+ 本地落盘 + 七牛 Kodo S3 兼容上传 → `POST /v1/uploads/images`；S3 失败自动降级本地
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
- [x] AI 润色/短诗（OpenAI 兼容接口）—— 失败抛 FeatureDisabled
- [x] LLM 审核分类接入 moderation；七牛 Kodo S3 兼容存储已接入（降级本地）
- 每项接完必须重验关闭分支

**后端 P0 合计约 5 人日。**

---

## 2. 前端路线（apps/app）

依赖链：`F0 数据层 → F1 应用基础设施 → F2 写信最小闭环 → F3 阅读器基础 → F4 收信双入口 → F5 回信/通知 → F6 我的信`，F7 汇总 P1 增强。

**开工门槛**：F0/F1 未通过前不得进入业务页面。一个页面若需要定位、权限、生命周期或通用布局，只能消费 F1 的全局能力，不能在 feature 内另起实现。

### F0 · 数据层与认证引导（0.5 天）
- [x] `secure_store`：首启生成 device_id（UUIDv4）存安全存储
- [x] 启动引导：静默 `POST /v1/auth/device` 换 JWT（401 自动重绑一次）
- [x] `data/api` 按资源补 endpoint 封装（letters/drift/discover/me/ai/uploads/weather/geo/catalog）
- [x] 验证 ApiClient 对 **204 无 body 响应**的容错（postJson 现假定 JSON body）
- [x] 补模型：LetterOwned、NotificationPublic、ThemePublic、TagPublic（现在只有 LetterPublic 一族）
- [x] 删除重复的 `AuthApi` 路径与脚手架 `healthProvider`；认证只有 `ApiClient` 一个所有者
- **验收**：冷启动无感登录；`make check-dart` 过

### F1 · 应用基础设施（0.5–1 天，全页面阻塞项）
- [x] `KazeScaffold`：统一天空背景、AppBar、SafeArea、内容宽度与滚动；普通页面不再重复搭壳
- [x] 通用 `PermissionController`：统一 check/request/open settings 与显式状态；feature 不直接依赖插件
- [x] 全局 `LocationController`：写信、发掘和首页环境共享坐标；区分服务关闭、拒绝、永久拒绝和失败
- [x] `AppLifecycle`：回前台刷新已使用过的权限/定位，冷启动不主动弹系统权限
- [x] Android 主清单声明网络 + 前台粗/精确定位；iOS Info.plist 声明前台定位用途；不提前申请相机/相册/存储权限
- [x] 设计系统 `TextStyle` 声明 package 命名空间，修复已打包字体静默回落系统字体
- [x] 设计系统 tokens/components 已拷入并接到 `KazeTheme`；后续只通过 `make sync-ds` 同步上游
- [x] 架构复核修正：会话预热移到首帧后；Web 定位权限映射为插件实际支持的 `Permission.location`
- [x] Android 仅 debug 放行局域网 HTTP；iOS 声明本地网络用途并只放行 local networking，release/公网仍要求 HTTPS
- [x] 2xx 响应严格解析：分页缺 `items`、目录坏项、必填字段错型统一报 `invalidResponse`，不伪装空状态
- **验收**：controller 单测覆盖权限与定位主要分支；`TextStyle.fontFamily` 与 `FontManifest.json` 一致；Web 与 iOS Simulator 可视确认字体；iOS Simulator 构建/安装/启动通过；`make check-dart` 过

### F2 · 写信最小闭环（1.5–2 天，全 App 最复杂）
- [x] `WriteController` + 分步流：blocks 图文编辑 → 落点确认 → **必选留/投**；P0 固定 `theme_id=natsu` 且默认皮肤，不把音乐/标签/皮肤搭配混进首个闭环
- [x] 图片 gateway：系统 picker 限长边与质量，按实际字节识别 MIME，顺序上传；~~用 iOS 真机照片验证 HEIC→JPEG 输出~~（本环境无 iOS 设备，HEIC→JPEG 转码路径待真机补验）
- [x] 建立 `DropPoint(lat, lon, publicLabel)`：消费全局 `LocationController` 的候选值后由用户确认；改地名不改坐标，只有地名时不得提交 stay
- [x] 客户端校验镜像产品与契约：整封文字 ≤800、单块 ≤800、blocks 1–20、照片 ≤3、照片手记 ≤200、署名/宛名 ≤32、地点 ≤128
- [x] `DraftStore`：版本化 JSON + 应用目录图片引用 + 防抖自动保存；只保证离开/断网不丢编辑，不做离线发送队列
- [x] 留/投二选一的 UI 必须是显式一步，不许有默认值悄悄带过（PRD 6.1 必选）
- **验收**：stay 与 drift 各写成一封；断网时草稿还在；AI 关闭时写信流纯手动可走通 —— ✅ 2026-08-26 模拟器 E2E：drift（正文+3 图+署名宛名）与 stay（定位落点+天气）均落库；杀进程草稿恢复；`USE_MOCK_API` 无后端寄出。附带修复后端 `letter_service` weather 未 model_dump 进 JSONB 的 503

### F3 · 阅读器基础（1 天，提前消除汇合风险）
- [x] 集中实现 data model → 设计系统 view model 的单向 mapper（`features/reader/letter_view.dart`，短诗/音乐/skin 本阶段丢弃）；图片 resolver 统一走缓存网络图，不在页面散写映射
- [x] 信纸渲染：`地点·时间·天气` + blocks 图文流 + 共鸣句子式计数（组件库 `NatsuResonance.sentence`）。短诗/音乐/skin 的专门展示位顺延
- [x] `ReaderController`：加载（loading/ready/notFound/error 四态 + 空态文案）、markRead 调用边界（失败静默）、✦ 共鸣幂等乐观回显（乐观落章→服务端校正→失败回滚）、回信入口（带 parent 跳 F2）、举报（AppBar「⋯」菜单 + 预设理由弹层）
- [x] 溯源：parent_letter_id 非空可跳原信（public 才可达，404 就 404）
- **验收**：PRD 6.3 展示项全齐；页面上不存在任何作者位 —— ✅ 2026-08-27 真实接口 E2E（种子信）：图文流/meta 渲染、共鸣计数 0→1 且重启幂等、回信跳 F2、举报 204、404 空态；`make check-dart` 全绿。另：KazeScaffold 增加 `bottom` 槽位、router 支持 `INITIAL_ROUTE` dart-define 调试直通车（F4 接 UI 入口前的 E2E 手段）、MockApiAdapter 补读信端点

### F4 · 收信双入口（1 天）
- [x] drift：抽信只展示 `Envelope`，用户拆封后 `markRead` 恰一次再进入 F3 阅读器；池空展示叙事态「此刻还没有漂来的信」（实现口径：markRead 由 ReaderController 进入即幂等上报，drift/discover 侧不重复调；开信走 `pushReplacement`——拆封是一次性仪式）
- [x] discover：定位 → 半径预设（Env.discoverRadiusM）→ 附近信列表（时间序）→ 点开 markRead → F3 阅读器
- [x] 定位统一走 `LocationController`；拒绝时允许重试/开启设置或输入真实坐标，禁止默认坐标和仅地名伪成功（本阶段做「重试 + 去系统设置」，手动输坐标留待需要时再加）
- **验收**：双入口并列可达；收信与已读语义分离；driftPoolEmpty 呈现为叙事状态 —— ✅ 2026-08-27 mock E2E：抽信→封筒（宛名/邮戳/皮肤）→开信→阅读器；换一封→池空叙事；发掘定位卡（复用逆地理地名 + 半径/计数）→俳句卡/预览卡→点开进阅读器，读完返回列表已排除该信（RouteAware didPopNext 整页重刷）；漂流重进即重置到第一幕。附：共享 `LetterSummaryCard`（俳句三行衬线排版，距离槽留待后端补字段，已记 COPY_IN 待上游化）、`NarrativeCard`、mock 补 drift/discover 路由与已读排除。画布偏差（用户裁决）：中央信封图案、「纯随机 · 不做加权」hint、卡片歪斜与大标题头不实现；按钮 r26→令牌小圆角

### F5 · 回信 + 通知（0.5–1 天）
- [x] 回信复用写信流（router 已留 `?parent=`），入口文案「回以一封信」，写完同样选留/投（F2/F3 已预埋 parentLetterId/createReply/`reply_<parent>` 草稿键，本阶段补齐文案统一）
- [x] app 级 `UnreadCountController` 为抽屉角标唯一所有者；notifications feature 只拥有列表/已读，二者单向同步（markRead 成功后 `decrement()`；unread_only=true&limit=50，v1 无 total 字段、条数即计数；失败静默保留旧值）
- [x] notifications 列表 + 已读 + 点击跳公开回信；开页与回前台拉取挂到 `AppLifecycle`（不做轮询、不建推送）（列表顶对齐为用户裁决：条目少时不浮在屏幕中部；角标一位数正圆、两位数胶囊）
- **验收**：回信发布后，原信作者设备上出现告知并能读到回信 —— ✅ 2026-08-27 真实后端跨设备：curl 设备 A 创建原信 → App（INITIAL_ROUTE 直通车）回信落库（`POST replies 201`）→ 设备 A notifications 出现未读告知、回信公开可读 → unread_only 1 条 → markRead 204 归零。附：`core/relative_time.dart` 共享相对时间、mock 补 notifications 路由与回信种子（含 dio queryParameters bool 原始类型坑修复）；`make check` 全绿

### F6 · 我的信（P0，0.5 天）
- [x] 我的信：LetterOwned 渲染 + 状态徽标（pending/public/…）+ 下架确认（非硬删）（操作信件的交互形式为**长按弹底部交互区**——用户裁决；非公开信点按也弹同区解释而非阅读器 404，公开信保留点按直读）
- **验收**：下架后读者侧 404，回信链不塌 —— ✅ 2026-08-27 双轨验收：真实后端 curl 六步（设备 A 投信 public → 设备 B 回信落库 → 作者 DELETE 204 → 读者侧 GET 404 → 回信本体仍 200 → my_letters 落库 taken_down 且保留落点）；模拟器 mock E2E 四态徽标列表 → 长按操作区（状态句 + destructive）→ 两段式确认 → 徽标原地翻「已下架」→ 已下架卡点按弹解释区。附：`MeApi.myLetters/deleteLetter` 首次接入 UI、共享 `core/letter_preview.dart` 抽取口径（discover_view 同步改调用）、`LetterSummaryCard` 补 `statusLabel`(NatsuTag sm 纯文字)/`onLongPress`（发掘列表不受影响，COPY_IN 已更新）、mock 补 me/letters 四态种子 + DELETE + 本人公开信详情白名单（下架后 mock 详情同样 404）；app 165 测试 + 组件库 105 测试全绿

### F7 · P1 表达与留存增强（P0 闭环后）
- [ ] 写信增强：音乐引用、1–3 标签、皮肤槽位选择；不改变历史信件 skin
- [x] 抄本：收藏列表 + 移除 —— ✅ 2026-08-27：后端三端点已就位零改动；前端 ScripbookScreen/ScripbookController 按 MyLetters 骨架落地（四相 + RouteAware 静默刷新 + 长按两段式移出），入口挂 reader「⋯」菜单 `saveToScripbook`（幂等恒可点 + notice toast），MockApiAdapter 补 GET/POST/DELETE scripbook 与种子；app 184 测试全绿。note 字段暂不开 UI，导出留后续
- [ ] 导出：复用设计系统 `LetterExportBoundary`，移除重复 screenshot 依赖；补“仅添加到相册”能力及对应 iOS 用途说明
- [ ] 完整离线写作：如确有需要，再设计待发送队列与冲突/重试；不与 P0 草稿自动保存混为一谈

**前端 P0 合计约 5.5–7 人日。**

---

## 3. 联调节点与排期

| 节点 | 前置 | 内容 |
|---|---|---|
| J1 | B2 + F2 | 写信端到端：App 写 → 落库 → status 正确 |
| J2 | B3+B4 + F3–F5 | 双入口收信 + 阅读 + 共鸣 + 回信 + 通知 |
| J3-P0 | B6 + F2–F6 | 双设备核心验收（埋信→发掘→共鸣→回信→通知；投递→收到→拆封） |
| J3-P1 | F7 | 增强验收（音乐/标签/皮肤、抄本、导出），不阻塞 P0 判定 |

### 单人顺序（推荐）
```
B0 → B1 → B2 → F0 → F1 → F2 →(J1)→ B3 → B4 → F3 → F4 → F5 →(J2)→ B5 → F6 → B6 →(J3-P0)
→ B7/F7 按余量
```

### 双人并行
```
后端线：B0 → B1 → B2 → B3 → B4 → B5 → B6 → B7
前端线：  F0 → F1 → F2 → F3 → F4 → F5 → F6 → F7
              └──J1──┘    └────J2────┘      └─J3─┘
```

按剩余工作量执行，不再用过期自然日倒排：先 F2/J1，再 F3 阅读器基础，随后 F4–F5/J2，最后 F6/J3-P0；任何 P1 项不得插到核心闭环之前。

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
| 7 | ~~迁移文件硬编码 `schema="dev_limpid"`~~（已解决：迁移使用连接 `search_path`，PostGIS 固定安装在 public） | — | 新数据库执行 `make migrate` 冒烟验证；DB 业务测试仍用独立 `test_<name>` schema |
| 8 | ~~页面直接调用定位/权限插件，形成多份当前坐标和拒绝分支~~ | — | F1 全局 controller + gateway；feature 禁止直接 import 插件 |
| 9 | ~~依赖包字体已打包但 family 带 package 前缀，token 引用无前缀导致回落系统字体~~ | — | token 的 `TextStyle` 显式传 package；构建产物检查 FontManifest |
| 10 | 真机用 HTTP 局域网 API，发布环境必须 HTTPS | 验收日网络失败或误把明文配置带进 release | Android 仅 debug 放行；iOS 仅 local networking；demo 前核对 API_BASE_URL、图片 public_base_url/S3 与双设备可达性 |
| 11 | ~~设置页“主题随环境变化”只有持久化、没有实际消费者~~ | — | 已撤下假开关及死存储链路；接入真实天气/时段主题与消费端测试后再恢复 |

---

## 5. 每个里程碑的完成定义

1. `make check`（后端含 `not db` 测试 / 前端 analyze + test）全绿
2. 涉及 endpoint 的，`make openapi` 后 git diff 无契约漂移
3. 可降级模块同时验证开启与关闭两条路径
4. 匿名守卫（test_anonymity / widget_test）持续绿——红了先怀疑自己的 schema，不是测试
