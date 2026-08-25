# 风信 · 架构说明

> 本文描述**模块边界与数据流**，由 `PRD.md` §10 展开。产品规格以 PRD 为准，行为约束见根 `CLAUDE.md`。

---

## 1. 总体形态

```
┌─────────────────────────────────────────┐
│  Flutter App (apps/app)                 │
│  iOS / Android 客户端 · Web 演示兜底      │
│  Riverpod 状态 / go_router 路由 / dio    │
└──────────────────┬──────────────────────┘
                   │ REST + JWT (Bearer)
┌──────────────────▼──────────────────────┐
│  FastAPI (services/api)                 │
│  ┌────────────────────────────────────┐ │
│  │ api/v1/  router 层：只做 HTTP 转换  │ │
│  ├────────────────────────────────────┤ │
│  │ services/ 业务层：8 个模块          │ │
│  ├────────────────────────────────────┤ │
│  │ models/  SQLAlchemy 2.0            │ │
│  └────────────────────────────────────┘ │
└──────────────────┬──────────────────────┘
                   │ asyncpg
┌──────────────────▼──────────────────────┐
│  PostgreSQL + PostGIS（比赛云服务器）    │
│  per-developer schema: dev_<name>        │
│  PostGIS extension 装在 public           │
└─────────────────────────────────────────┘

外部依赖（全部可降级，PRD §8.3）：
  LLM（润色/短诗/审核）· 天气 API · 逆地理 · 对象存储
```

---

## 2. 后端 8 个模块（对应 PRD §10）

| 模块 | 目录 | 职责 | 降级行为 |
|---|---|---|---|
| ① 信服务 | `services/letter_service.py` | 信件存取、状态机、计数自增 | 不可降级（核心） |
| ① 漂流分发 | `services/drift_service.py` | 随机抽取（排除自己/已开封/冷却内送达） | 不可降级（核心） |
| ① 地理发掘 | `services/discover_service.py` | `ST_DWithin` 附近检索 | 不可降级（核心） |
| ② 账户服务 | `services/`（薄，逻辑在 `core/security.py`） | 设备绑定、JWT | 不可降级 |
| ③ 回信与通知 | `services/reply_service.py` | `parent_letter_id` 溯源 + 告知原作者 | 无 owner 的信静默跳过通知 |
| ④ 共鸣/抄本 | `services/resonance_service.py` | ✦ 计数、抄本收藏 | 不可降级 |
| ⑤ 主题/导出 | `api/v1/themes.py` | 皮肤与标签元数据 | 静态目录，无外部依赖 |
| ⑥ AI | `services/ai_service.py` | 润色、短诗 | `FEATURE_AI=false` → 写信流纯手动 |
| ⑦ 位置天气 | `services/geo_service.py` `weather_service.py` | 逆地理、天气 | 关闭 → 落点仅存坐标与用户手填地名 |
| ⑧ 审核 | `services/moderation_service.py` | 关键词 + LLM 分类 | **失败/关闭 → 一律 `pending`，绝不 `public`** |

**导出图片（PRD 6.11）不在后端**：用 Flutter 端 `RepaintBoundary` 渲染，比服务端无头渲染便宜一个数量级。

### 分层纪律

- `api/v1/*.py` 只做：解析请求 → 调 service → 转成 response schema。**不写业务逻辑，不直接写 SQL。**
- `services/*.py` 承载全部业务规则，接收 `AsyncSession` 参数，不感知 HTTP。
- `models/` 只描述表结构，不含业务方法。
- 外部调用一律在 `services/` 里包一层，带超时与降级分支，**不许在 router 里直接 httpx**。

---

## 3. 信件状态机

```
       创建（默认 pending）
            │
     ┌──────▼──────┐
     │  pending    │ 审核中，不可被发掘/抽取
     └──┬───────┬──┘
    通过 │       │ 违规
     ┌───▼──┐ ┌─▼────────┐
     │public│ │ rejected │
     └───┬──┘ └──────────┘
   所有者下架│
     ┌───▼────────┐
     │ taken_down │
     └────────────┘
```

只有 `status='public'` 的信参与漂流抽取与就地发掘。`FEATURE_MODERATION=false` 时新信停在 `pending`，靠 `scripts/seed_letters.py` 或后续控制台手工放行——**降级方向永远是更保守，不是更开放**。

---

## 4. 两条核心数据流

### 投递出去 → 随机漂流（Drift）

```
写信 POST /v1/letters {delivery_mode:"drift"}
  → moderation → status=public
  → 入池

读者 GET /v1/drift/next
  → WHERE status='public' AND delivery_mode='drift'
      AND (owner_user_id IS NULL OR owner_user_id <> me)
      AND id NOT IN (SELECT letter_id FROM letter_reads WHERE user_id=me
                     AND (opened_at IS NOT NULL          -- 已开封：永不再现
                          OR served_at > now()-cooldown)) -- 冷却内：暂不复现
    ORDER BY random() LIMIT 1
  → 写 letter_reads.served_at（收信去重，不动 read_count）
  → 返回 LetterPublic（无作者字段）

读者打开信纸 POST /v1/letters/{id}/read
  → letter_reads.opened_at: NULL→now 迁移成功才 read_count+1（幂等，唯一自增点）
```

`ORDER BY random()` 在 demo 量级足够（PRD §8.4 要求 <1s）。**禁止引入任何相似度/兴趣加权**——那与赛道「制造一点意外」相悖，也违反 CLAUDE.md 红线 2。

### 留在这里 → 就地发掘（Stay）

```
埋信 POST /v1/letters {delivery_mode:"stay", lat, lon}
  → location = ST_MakePoint(lon,lat)::geography

发掘 GET /v1/discover?lat=&lon=&radius_m=
  → WHERE status='public' AND delivery_mode='stay'
      AND ST_DWithin(location, ST_MakePoint(:lon,:lat)::geography, :radius_m)
    ORDER BY created_at DESC
  → 走 ix_letters_location_gist
```

用 `Geography(POINT,4326)` 而非 `Geometry`：`ST_DWithin` 直接以米为单位，省掉投影换算。

### 回信链（PRD 6.5）

回信是**独立信件**，不是私信：

```
POST /v1/letters/{id}/replies  → 新建 letters 行，parent_letter_id = {id}
  → 原信 reply_count + 1
  → 若原信 owner_user_id 非空 → 插入 Notification(type='reply')
  → 若为空（纯过客所写）→ 静默跳过，回信照样公开
```

原作者**不是**回信的收件人。禁止建 DM/conversation/thread 表。

---

## 5. 前端结构（feature-first）

```
lib/
├─ app/      router / theme / bootstrap / lifecycle
│  ├─ controllers/  应用级状态（permission / location；F5 再加 unread）
│  ├─ permissions/  权限语义与平台 gateway
│  └─ widgets/      KazeScaffold 等跨 feature UI
├─ core/     env / result / formatters
├─ data/     api（dio + 各 endpoint）/ models / local（安全存储、草稿）
│            / device（定位等平台能力的窄接口）
└─ features/ write · drift · discover · reader · reply
             my_letters · scripbook · notifications · settings
```

feature 不强制为目录完整而制造文件：有异步状态时才加 `*_controller.dart`，有两个以上局部组件时才建 `widgets/`。单一远程数据源可由 controller 直接消费窄 API；只有本地持久化、多数据源编排或缓存策略才引入 repository，禁止“每个 feature 必配 repository”的仪式性分层。

- feature 之间**不得互相 import**；共享逻辑上提到 `core/` 或 `data/`。
- 网络只经 `data/api/api_client.dart`（统一 JWT 拦截器与错误映射）。
- **禁止字面量颜色/字号/间距**，一律走 `Theme.of(context)` 或设计系统 token——这样上游组件库拷入时不需要改 feature 代码。

### 5.1 应用级基础设施边界

页面开发前必须先完成以下地基，feature 不得自行复制：

| 能力 | 唯一所有者 | feature 可以做 | feature 禁止做 |
|---|---|---|---|
| 权限 | `PermissionController` | 在用户触发的场景解释用途并调用 `request` | 直接 import `permission_handler`、自行映射永久拒绝 |
| 定位 | `LocationController` | 读取共享坐标、触发 `locate`、展示手填降级 | 直接调用 `Geolocator`、另存一份“当前坐标” |
| 页面骨架 | `KazeScaffold` | 提供标题、正文、actions | 重复搭天空背景/AppBar/SafeArea/宽度约束 |
| 回前台刷新 | `AppLifecycle` | 注册确有生命周期需求的全局 controller | 每个页面各挂一个 `WidgetsBindingObserver` |

权限与定位的数据流：

```
用户在写信/发掘页点“使用当前位置”
  → LocationController.locate(requestPermission: true)
  → PermissionController（check → 必要时 request）
  → LocationGateway（仅权限通过后调用 Geolocator）
  → AppLocationState.ready(coordinate)
  → 写信 / 发掘 / 首页环境消费同一份坐标
```

约束：

- 冷启动不自动申请权限；系统权限弹窗必须由清晰的用户动作触发。
- `denied`、`permanentlyDenied`、定位服务关闭和插件失败是四种显式状态，不得合并成空坐标或吞掉。
- `LocationController` 只拥有“设备最近一次测得坐标”，不拥有写信表单选择。写信 controller 必须把用户确认过的候选坐标复制成 `DropPoint(lat, lon, publicLabel)`；修改公开地名不等于修改精确落点。
- 定位失败不阻断写信：用户仍可改选 drift。stay 必须有真实坐标，只有 `place_label` 不能提交；后续地点搜索/地图选择也必须产出明确坐标，禁止用默认坐标伪成功。
- 回到前台只刷新已经使用过的权限/定位；没有请求过定位时保持 idle。
- 平台清单只声明当前功能真实使用的权限。Android P0 为 `INTERNET`、`ACCESS_COARSE_LOCATION`、`ACCESS_FINE_LOCATION`；iOS 为 `NSLocationWhenInUseUsageDescription`。iOS 本地后端调试另声明局域网用途与 `NSAllowsLocalNetworking`；Android 只在 debug manifest 放行明文 HTTP，release 必须 HTTPS。两端都不预申请相机、相册或存储权限。

### 5.2 通用页面骨架

`KazeScaffold` 是普通页面的默认入口，统一负责天空渐变、透明 Material Scaffold、AppBar、SafeArea、480px 内容宽度和滚动容器。首页因包含 Drawer 与独立布局保留定制 Scaffold；信件全屏阅读器若需要特殊画布，可显式使用专用壳，但必须在文件头说明偏离原因。

### 5.3 启动、会话与协议错误

应用启动顺序固定为：同步装配 `SecureStore` / `ApiClient` → `runApp` → 首帧回调中 fire-and-forget 会话预热。不得在 `runApp` 前等待网络或 SharedPreferences。业务请求若早于预热完成，`ApiClient` 的 401 合并重绑负责自愈。

服务端返回 2xx 不代表数据有效：endpoint 模型解析统一经 `ApiClient.decode`，分页 `items` 缺失、列表坏项和必填字段类型错误都映射为 `ApiFailure.invalidResponse`。这些情况是契约漂移，必须展示可重试错误并记录，不能用 `whereType`、默认空列表或吞 TypeError 伪装成“暂无内容”。

feature 异步状态统一使用 Riverpod `AsyncValue` / `AsyncNotifier`：

- loading、可重试 error、业务 empty 是三种状态；`driftPoolEmpty` 属于叙事 empty，不是红色错误。
- AI、天气、逆地理等明确可降级模块，只在其 API 边界把 `featureDisabled` / `serviceUnavailable` 转成 null；其他错误继续上抛。
- 在首个真实异步页面落地时再提取共享状态视图，当前不预建无人消费的 `AsyncView`。

### 5.4 草稿、图片与渲染边界

- 草稿自动保存属于 P0 的编辑韧性；“离线提交队列/网络恢复自动发送”仍是 P1，两者不得混写为一个验收项。
- `DraftStore` 保存带 schema version 的 JSON；原图先复制到应用文档目录再引用，不能长期依赖 iOS picker 临时路径，也不能把图片字节塞进 SharedPreferences。
- 图片按顺序处理：系统 picker → 长边限制/质量压缩 → 从实际输出识别 JPEG/PNG/WebP → 单张顺序上传。当前 iOS picker 会把 HEIC 输出为 JPEG，无需提前引入第二套转码库；实现时必须用真机照片回归。
- API `LetterBlock` 与设计系统的渲染 `LetterBlock` 是两套边界模型。F3 阅读器开工前增加一个集中、单向的 view mapper；feature 页面不得各写一份映射。

### 5.5 状态唯一所有者

| 状态 | 唯一所有者 | 持久化/刷新 |
|---|---|---|
| JWT / device_id | `ApiClient` + `SecureStore` | 安全存储；401 合并重绑 |
| 权限 | `PermissionController` | 系统状态；只在用户触发或已使用能力回前台时刷新 |
| 设备坐标 | `LocationController` | 仅内存；携带精度与测量时间 |
| 写信落点与表单 | `WriteController` | `DraftStore`；由用户确认，不与设备坐标双向绑定 |
| 抽信/封筒状态 | `DriftController` | 仅 feature 内；拆封时 markRead 恰一次 |
| 单信与共鸣回显 | `ReaderController` | 远程真值；允许幂等乐观更新 |
| 通知未读数 | F5 新增 app 级 controller | 开页/回前台拉取；抽屉只消费 |
| 设置偏好 | 对应设置 controller | 只有存在真实消费者后才暴露开关，禁止“能保存但不生效” |

### 设计系统边界

`packages/natsu_no_tegami/` 已于 `6bf5204` 完成拷入，包含 9 个令牌文件、18 个通用组件、17 个信件组件、15 个字体、14 个测试文件。设计系统源改动原则上先落上游，再跑 `make sync-ds`；当前字体 namespace 修复是唯一待回灌上游的同步差异，脚本会拒绝用不含该修复的旧上游覆盖本包。

Flutter 会给依赖包 `pubspec.yaml` 声明的字体 family 加 `packages/natsu_no_tegami/` 命名空间。设计系统的每个 `TextStyle` 因此必须传 `package: 'natsu_no_tegami'`，让主 family 与 fallback 同时命中构建产物；只声明字体文件、不带 package 参数会静默回落到系统字体。字体验收不能只看文件存在，必须核对 `TextStyle.fontFamily` 与构建后的 `FontManifest.json` family 一致，并至少做一次 Web/Android 可视冒烟。

---

## 6. 匿名铁律的执行点

匿名不是靠"记得别返回作者"，而是靠**类型系统**：

- `schemas/letter.py` 的 `LetterPublic` **不存在** `owner_user_id` 字段。任何信件响应都必须用它。
- 需要作者视角的接口（我的信、下架）用独立的 `LetterOwned` schema，且只在 `/v1/me/*` 路径下、必须带 JWT。
- `tests/test_anonymity.py` 断言 `LetterPublic.model_fields` 不含任何作者字段——加回去就红。

---

## 7. 环境与部署

- **本地开发**：后端跑在本机，数据库连比赛云服务器的远程 PostGIS（本机无 Docker）。每人一个 `dev_<name>` schema。
- **云端部署**：`infra/docker-compose.yml`（postgis + api + minio），满足 PRD §11 DoD。本地不跑。
- **App 真机调试**：`API_BASE_URL` 要用局域网 IP，不能用 `localhost`。
