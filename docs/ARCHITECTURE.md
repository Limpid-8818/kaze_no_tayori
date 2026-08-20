# 风信 · 架构说明

> 本文描述**模块边界与数据流**，由 `PRD.md` §10 展开。产品规格以 PRD 为准，行为约束见根 `CLAUDE.md`。

---

## 1. 总体形态

```
┌─────────────────────────────────────────┐
│  Flutter App (apps/app)                 │
│  Android 主 · Web(edge) 演示兜底         │
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
| ① 漂流分发 | `services/drift_service.py` | 随机抽取（排除自己/已读） | 不可降级（核心） |
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
      AND id NOT IN (SELECT letter_id FROM letter_reads WHERE user_id=me)
    ORDER BY random() LIMIT 1
  → 写 letter_reads + read_count+1
  → 返回 LetterPublic（无作者字段）
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
├─ app/      router / theme / bootstrap（theme.dart 是唯一 import 设计系统的地方）
├─ core/     env / result / formatters
├─ data/     api（dio + 各 endpoint）/ models（freezed）/ local（安全存储、草稿）
└─ features/ write · drift · discover · reader · reply
             my_letters · scripbook · notifications · settings
```

每个 feature 固定三件套：`*_screen.dart`（UI）+ `*_controller.dart`（`@riverpod` Notifier）+ `widgets/`。

- feature 之间**不得互相 import**；共享逻辑上提到 `core/` 或 `data/`。
- 网络只经 `data/api/api_client.dart`（统一 JWT 拦截器与错误映射）。
- **禁止字面量颜色/字号/间距**，一律走 `Theme.of(context)` 或设计系统 token——这样上游组件库拷入时不需要改 feature 代码。

### 设计系统边界

`packages/natsu_no_tegami/` 当前是**空壳 + 临时主题（shim）**。上游真实组件库在独立仓库开发，成形后按 `packages/natsu_no_tegami/COPY_IN.md` 整体拷入并删除 shim。monorepo 内**永不手改**该包。

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
