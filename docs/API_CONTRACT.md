# 风信 · 前后端接口契约 v1

> 由 `PRD.md` §9 实体推导。**契约先于实现**：改 endpoint 必须同步本文并跑 `make openapi`。
> 与 PRD 的偏差一律记录在第 5 节，不许静默偏离。

约定：
- 前缀 `/v1`，JSON，UTF-8。时间为 ISO 8601 带时区。id 为 UUID 字符串。
- 认证：`Authorization: Bearer <jwt>`。除 `/health`、`/v1/auth/device`、`/v1/themes`、`/v1/tags` 外均需要。
- 错误体统一：`{"error": {"code": "letter_not_found", "message": "...", "detail": null}}`
- 分页：`?limit=20&cursor=<opaque>`，响应 `{"items": [...], "next_cursor": null}`。

---

## 1. 数据模型（表）

### users
| 列 | 类型 | 说明 |
|---|---|---|
| id | UUID PK | |
| device_id | text UNIQUE | 客户端生成的 UUIDv4，设备绑定用 |
| email | text NULL UNIQUE | P1 可选升级 |
| password_hash | text NULL | P1，argon2 |
| created_at | timestamptz | |

**不存任何画像字段**（PRD §8.1 数据最小化）。

### letters
| 列 | 类型 | 说明 |
|---|---|---|
| id | UUID PK | |
| blocks | jsonb NOT NULL DEFAULT `'[]'` | 图文交替流数组，见下 |
| poem | text NULL | AI 短诗，≤4 行 |
| signature | varchar(32) NULL | 信尾署名，写信人自填（可空 = 不署名）。内容物，非作者标识 |
| addressee | varchar(32) NULL | 宛名（封筒封面收信人），写信人自填。内容物，非读者标识 |
| theme_id | varchar(32) NOT NULL DEFAULT `'natsu'` | 基础主题 ID，指向 themes 表 |
| theme_skin | jsonb NULL | 皮肤搭配，见下。**全 null = 全默认**（不携带皮肤的信） |
| music_ref | jsonb NULL | `{album, song, lyrics}`，**不许加 url** |
| location | geography(POINT,4326) NULL | stay 必填，drift 可空 |
| place_label | varchar(128) NULL | 地点名（逆地理或手填） |
| weather | jsonb NULL | `{text, temp_c, icon}` |
| tags | jsonb NOT NULL DEFAULT `'[]'` | 1–3 个标签 id（P1） |
| delivery_mode | enum(`stay`,`drift`) NOT NULL | |
| status | enum(`pending`,`public`,`rejected`,`taken_down`) NOT NULL DEFAULT `pending` | |
| owner_user_id | UUID FK users NULL | 纯过客可空（PRD 6.5 可达性边界） |
| parent_letter_id | UUID FK letters NULL | 回信溯源 |
| expire_at | timestamptz NULL | **恒 NULL**，预留不启用 |
| read_count / resonance_count / voice_count / reply_count / saved_count | int NOT NULL DEFAULT 0 | 叙事计数 |
| created_at | timestamptz NOT NULL | |

**blocks 结构**（jsonb 数组，每项带 `type` 区分）：
```
{"type": "text",  "text": "一段手写正文"}        # TextBlock
{"type": "photo", "ref": "https://…",             # PhotoBlock
 "mood": "overexposed",          # none|overexposed|backlit|motion
 "note": "正午的海"}             # 可选手记
```
约束：最少 1 块，最多 20 块，其中照片 ≤ 3 张。应用层校验，不建 DB CHECK。

**theme_skin 结构**（jsonb 对象，空槽省略键 = 用默认值）：
```json
{
  "stamp": "stamp-summer-01",
  "postmarkEmblem": "emblem-wave",
  "decor": ["decor-firefly", "decor-star"],
  "postcard": "postcard-beach"
}
```
`stamp` / `postmarkEmblem` / `postcard` 单选（null = 默认），`decor` 可多枚。
一旦写入永久绑定该信，禁止批量 UPDATE。

### letter_reads
| 列 | 类型 |
|---|---|
| letter_id | UUID FK letters |
| user_id | UUID FK users |
| served_at | timestamptz（drift 抽取送达时间） |
| opened_at | timestamptz NULL（开信时间，NULL = 收到未开封） |

PK `(letter_id, user_id)`。**PRD 未列，是 6.3「未读过」需求的必需推导实体**（见第 5 节）。
一行两层语义（**收信 ≠ 已读**）：`served_at` 服务于「不重复给同一个人同一封信」的
冷却去重；`opened_at` 服务于 discover 已开封过滤与 `read_count` 计数。

### resonance_logs
`id UUID PK` · `letter_id FK` · `user_id FK` · `note varchar(30) NULL` · `created_at`
UNIQUE `(letter_id, user_id)` —— 同一人只能共鸣一次。

### scripbook_entries
`user_id FK` · `letter_id FK` · `note text NULL` · `added_at`。PK `(user_id, letter_id)`。

### notifications
`id UUID PK` · `user_id FK` · `type varchar(16)`（P0 只有 `reply`）· `letter_id FK`（回信）· `parent_letter_id FK`（原信）· `is_read bool DEFAULT false` · `created_at`

### thought_tags
`id varchar(32) PK` · `name varchar(32)` · `color varchar(9)`。预置静态数据。

### themes
`id varchar(32) PK` · `name varchar(32)` · `assets jsonb` · `is_default bool`。P0 只有 `natsu`。

### admin_accounts
`id UUID PK` · `username UNIQUE` · `password_hash` · `role varchar(16)` · `created_at`。P1，与匿名用户体系隔离。

### 索引
| 名称 | 定义 | 用途 |
|---|---|---|
| `ix_letters_location_gist` | GiST(location) | 就地发掘 |
| `ix_letters_pool` | (status, delivery_mode) | 漂流池筛选 |
| `ix_letters_parent` | (parent_letter_id) | 回信溯源 |
| `ix_letters_owner` | (owner_user_id, created_at DESC) | 我的信 |
| `ix_notifications_inbox` | (user_id, is_read) | 通知列表 |

---

## 2. 响应体（匿名铁律的执行点）

### LetterPublic — 一切对外信件响应**只能**用它
```json
{
  "id": "uuid",
  "blocks": [
    {"type": "text", "text": "……"},
    {"type": "photo", "ref": "https://…", "mood": "overexposed", "note": "正午的海"}
  ],
  "poem": "……",
  "signature": "海边的风",
  "addressee": "远方的你",
  "theme_id": "natsu",
  "theme_skin": {"stamp": "stamp-summer-01", "decor": ["decor-firefly"]},
  "music_ref": {"album": "二人称", "song": "早朝、郵便受け", "lyrics": "……"},
  "place_label": "Tokyo",
  "weather": {"text": "小雨", "temp_c": 19.0, "icon": "rain"},
  "tags": ["travel", "sea"],
  "delivery_mode": "drift",
  "parent_letter_id": null,
  "counts": {"read": 12, "resonance": 3, "voice": 1, "reply": 1, "saved": 2},
  "me_resonated": true,
  "created_at": "2026-08-20T23:47:00+09:00"
}
```

**不含 `owner_user_id`、不含任何作者标识、不含精确坐标**（只给 `place_label`，避免反查作者位置）。

`me_resonated` 表示当前读者是否已经对该信共鸣。仅 `GET /v1/letters/{id}`
按登录用户查询；匿名访问以及列表类接口中的 `LetterPublic` 均为 `false`。

### LetterOwned — 仅 `/v1/me/*` 路径，仅本人
在 LetterPublic 基础上增加 `status`、`delivery_mode`、`lat`/`lon`（自己的信可见自己的落点）。**仍不含 owner_user_id**（自己不需要看自己的 id）。

---

## 3. Endpoints

### 健康检查
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/health` | 进程存活，不碰数据库。`{"status":"ok"}` |
| GET | `/health/db` | 连库 + `SELECT PostGIS_version()` |

### 认证（PRD 6.13）
| 方法 | 路径 | 请求 | 响应 |
|---|---|---|---|
| POST | `/v1/auth/device` | `{device_id}` | `{access_token, token_type:"bearer", user_id}` |
| POST | `/v1/auth/upgrade` | `{email, password}` | 同上（P1，绑定账号以跨设备） |
| POST | `/v1/auth/login` | `{email, password}` | 同上（P1） |

无密码、无强制注册。JWT payload 只含 `sub=user_id` + `exp`。

### 写信与投放（PRD 6.1）
| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/v1/letters` | 创建。body 见下。返回 `LetterOwned`（含 status，通常 `pending`） |
| POST | `/v1/uploads/images` | multipart，返回 `{url}`。压缩后存储 |

创建 body：
```json
{
  "blocks": [
    {"type": "text", "text": "海的彼岸……"},
    {"type": "photo", "ref": "https://…", "mood": "overexposed", "note": "正午的海"}
  ],
  "poem": null,
  "signature": "海边的风",
  "addressee": "远方的你",
  "theme_id": "natsu",
  "theme_skin": {"stamp": "stamp-summer-01", "decor": ["decor-firefly"]},
  "music_ref": {"album": "…", "song": "…", "lyrics": "…"},
  "tags": ["travel", "sea"],
  "delivery_mode": "stay",
  "lat": 35.68, "lon": 139.76,
  "place_label": "Tokyo",
  "weather": {"text": "小雨", "temp_c": 19.0}
}
```
`delivery_mode` **必填**（PRD 6.1：必选留/投）。`stay` 时 `lat`/`lon` 必填。照片 ≤3 张，最少 1 块正文。

### AI 辅助（PRD 6.2，可关）
| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/v1/ai/polish` | `{content}` → `{polished}`。保留原意，用户可选采纳 |
| POST | `/v1/ai/poem` | `{content}` → `{poem}`。从正文提取意象生成俳句（默认体裁），≤4 行，与正文同屏展示 |

`FEATURE_AI=false` 时返回 `503 {"error":{"code":"ai_disabled"}}`，前端降级为纯手动，**不阻断写信**。

### 环境服务（B7 可降级，失败返回 null / 503 不阻断写信）
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/v1/weather/now?lat=&lon=` | 当前天气 `{text, temp_c, icon}`；取不到返回 null |
| GET | `/v1/geo/reverse?lat=&lon=` | 逆地理：`{place_label}`（城市级，隐私截断）；取不到返回 null |

### 随机漂流（PRD 6.3）
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/v1/drift/next` | 抽一封非自己发、未被占用的 public+drift 信。返回 `LetterPublic`；池空返回 `404 drift_pool_empty` |

副作用：只写 `letter_reads.served_at`（送达去重），**不动 `read_count`**。
排除条件：已开封（永不再现）或冷却期内（`DRIFT_SERVE_COOLDOWN_S`，默认 3600s）送达过——
被丢弃的未开封信在冷却后回到池里，未来仍可漂来。**纯随机，禁止任何加权。**

### 就地发掘（PRD 6.4）
| 方法 | 路径 | 说明 |
|---|---|
| GET | `/v1/discover?lat=&lon=&radius_m=` | `ST_DWithin` 检索附近 public+stay 信。`radius_m` 默认取 `DISCOVER_RADIUS_M`（1000） |

响应 `{"items": [LetterPublic...], "next_cursor": null}`，按 `created_at DESC`。
不返回 viewer 已开封的信（`opened_at` 非空即过滤）。

### 阅读
| 方法 | 路径 | 说明 |
|---|---|
| GET | `/v1/letters/{id}` | 读单封 public 信（回信溯源用）。非 public 返回 404。纯读，无副作用；登录用户的响应按共鸣记录下发 `me_resonated` |
| POST | `/v1/letters/{id}/read` | 开信上报（收信≠已读）。204；幂等：首开 `read_count+1`，重复开不再计。非 public 返回 404 |

前端在信纸真正打开时调用（drift 解开封面 / discover 点开列表项皆然）。
`read_count` 全链路唯一自增点。

### 回信（PRD 6.5）
| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/v1/letters/{id}/replies` | body 同创建信。新建独立信件，`parent_letter_id={id}` |
| GET | `/v1/letters/{id}/replies` | 该信的公开回信列表（`limit` 1–50，默认 20） |

副作用：原信 `reply_count+1`；原信 owner 非空则插 `Notification`，为空则静默跳过（回信照样公开）。

### 共鸣（PRD 6.6）
| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/v1/letters/{id}/resonance` | `{note?: "≤30字"}`。幂等：重复调用返回 200 不重复计数 |

响应 `{"resonance_count": 4}`。**不返回共鸣者，不提供共鸣者列表接口。**

### 抄本（PRD 6.10）
| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/v1/me/scripbook` | `{letter_id, note?}` 收藏，`limit` 1–50，默认 20 |
| DELETE | `/v1/me/scripbook/{letter_id}` | 取消收藏 |
| GET | `/v1/me/scripbook` | 我的抄本列表，`limit` 1–50，默认 20 |

### 我的信
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/v1/me/letters` | 我写的信（`LetterOwned`，含 pending），`limit` 1–50，默认 20 |
| DELETE | `/v1/me/letters/{id}` | 下架（→ `taken_down`），非硬删 |

### 通知（PRD 6.5）
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/v1/me/notifications?unread_only=` | 列表 |
| POST | `/v1/me/notifications/{id}/read` | 标记已读 |

P0 只做拉取，不做推送。

### 静态目录
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/v1/themes` | 主题皮肤列表（P0 只有 natsu） |
| GET | `/v1/tags` | 预置思绪标签 |

### 举报（PRD 8.2）
| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/v1/letters/{id}/report` | `{reason}`。入库待人工处理 |

---

## 4. 明确不存在的接口

以下接口**永不实现**（CLAUDE.md 红线 2、PRD §7 §12）：

- ❌ 点赞 / 取消点赞、关注 / 粉丝
- ❌ 推荐 Feed、热门榜、趋势、排行
- ❌ 共鸣者列表、读者列表（任何能反查"谁读了/谁共鸣了"的接口）
- ❌ 作者主页、按作者查信
- ❌ 私信 / 会话 / 消息线程
- ❌ 单信轨迹、跨信热度对比
- ❌ 音频上传 / 音乐生成 / 外链音乐

---

## 5. 与 PRD 的偏差记录

| # | 偏差 | 原因 |
|---|---|---|
| 1 | 新增 `letter_reads` 表（served_at + opened_at） | PRD 6.3 要求抽「未读过」的信，`read_count` 只是聚合值无法判断个体已读。收信≠已读拆分后，served_at 服务送达去重、opened_at 服务开信计数与 discover 过滤。 |
| 2 | `LetterPublic` 不返回精确坐标，只返回 `place_label` | PRD §8.1「位置可控/可模糊到城市级」。精确坐标外泄可反查作者活动位置，与匿名精神冲突。`LetterOwned` 里本人可见。 |
| 3 | 新增 `POST /v1/letters/{id}/report` | PRD 8.2 要求举报入口，但 §9 未列实体。按最小实现落一张 `reports` 表。 |
| 4 | 导出图片无后端接口 | PRD 6.11 的渲染在 Flutter 端用 `RepaintBoundary` 完成，无需服务端。 |
| 5 | `music_ref`/`weather`/`tags`/`theme_skin` 用 jsonb 而非独立表 | 均为值对象、无需独立查询，jsonb 在 10 天赛期内更省事。若 P1 需要按标签聚合再抽表。 |
| 6 | `content` + `images` 合并为 `blocks` 图文交替流 | 上游设计系统采用 sealed class `LetterBlock`（TextBlock / PhotoBlock）替代 flat 字段，前端渲染与数据模型一致。 |
| 7 | `theme` 拆分为 `theme_id` + `theme_skin` | 基础主题 ID 指向 themes 表，皮肤搭配（stamp/postmarkEmblem/decor/postcard）是 jsonb 槽位搭配。空槽 = 默认，全空 = 不携带皮肤。 |
| 8 | 新增 `signature` / `addressee` 可空列 | PRD 6.1 未列的写信人自填内容物：信尾署名（信纸右下手写位）与宛名（封筒封面竖排收信人，PRD 6.3 信封呈现的数据源）。与正文同级，非作者/读者标识，匿名铁律不受影响；不持久化则 UI 输入无意义。 |
