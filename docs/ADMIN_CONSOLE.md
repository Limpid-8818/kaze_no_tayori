# 运营控制台设计（apps/admin）v1

> PRD 6.14，P1。形态与范围已裁决（2026-08-29）：**Flutter Web**；v1 = 审核队列 + 下架 +
> 举报处理 + 反馈管理 UI + 统计概览 + 种子信件管理（列表/新建/编辑/下架恢复）。
> 本文是 `apps/admin` 的设计事实来源；端点契约同步见 `API_CONTRACT.md` §3「管理端」。

---

## 1. 定调

- **形态**：`apps/admin` 独立 Flutter Web 应用。复用现有 Dart 工具链，不引入 Node/pnpm；
  复用 `packages/natsu_no_tegami` 的 **token 层**（色板/字体/小圆角令牌）。
- **设计纪律隔离**：管理端用中性密集工作台风格（白底、表格、表单、系统级布局），
  **不复用**叙事组件（KazeScaffold、天空背景、信封/叙事卡等）。只共享 token，
  不共享匿名端的页面组件——两端的「像」只到字体与色板为止。
- **鉴权**：复用 `POST /v1/admin/login`（typ=admin JWT，12h 时效）。token 存
  **sessionStorage**（标签页级，关页即失效）；401 统一踢回登录页。
  角色沿用 `admin|viewer`：所有写端点（PATCH/POST）挂 `require_role("admin")`，
  viewer 只读（403 `admin_forbidden`）。
- **红线遵守**（根 CLAUDE.md §2）：管理端可见 `owner_user_id`（本就是匿名设备 UUID），
  用途仅限区分种子信与举报处置，对访客「不暴露作者」的口径不变；
  不做任何反查读者/共鸣者的接口；种子信编辑不碰 theme 永久绑定与计数列；
  通知/作者身份等叙事红线不在管理端开口子。

## 2. 信息架构（7 页）

登录后进入工作台壳（左侧导航：概览 / 审核队列 / 信件管理 / 举报处理 / 反馈管理 /
种子信件），导航项带待办角标（待审 pending 数、open 举报数、open 反馈数，来自 stats）。

| 页面 | 内容与关键交互 |
|---|---|
| 登录 | 用户名 + 密码 → JWT。凭据错误一律「用户名或密码错误」不区分 |
| 概览 Dashboard | 状态分布卡（pending/public/rejected/taken_down）、用户数、7 日新增、漂流池健康度（drift 池可抽信数）、待办角标直达各队列 |
| 审核队列 | pending 信列表（时间序，缩略预览）→ 审核页：**左侧读者视角预览**（复用 natsu_no_tegami 信件渲染组件，所见即读者所见）+ 右侧操作面板（元信息/计数/落点/状态）。通过 → public、驳回 → rejected，均两段式确认 |
| 信件管理 | 全状态检索（按 status / delivery_mode / 是否种子信筛选，时间倒序），行内操作：下架（public→taken_down）、恢复（taken_down→public）、赦免（rejected→public，二次确认）。点行进与审核页同构的详情 |
| 举报处理 | open 举报列表（理由 + 详情 + 涉事信预览卡）→ 处置：**下架信件并标记 actioned**（复用信件状态机）/ **驳回 dismissed**；均已处理项默认隐藏，可切筛选查看 |
| 反馈管理 | 复用现有 GET/PATCH `/v1/admin/feedbacks`：status/category 筛选、admin_note 编辑、标记已处理/回退 |
| 种子信件管理 | **列表**（owner IS NULL 的信：状态、delivery_mode、落点、池内可抽性）、**新建**（blocks 图文编辑 + 落点坐标/地名 + 天气 + drift/stay，图传走 uploads；owner=NULL 直接 public 入池）、**编辑**（改 blocks/文案/落点/天气，二次确认；右侧实时预览）、**下架/恢复**（复用信件状态机）。页首展示漂流池健康度 |

要点：审核页与种子信编辑页共用「读者视角预览 + 操作面板」的双栏骨架；
预览与种子信编辑预览经集中 mapper 走 F3 `letter_view` 同源口径，保证所见即读者所见。

## 3. 后端补齐（services/api）

已有：`POST /v1/admin/login`、`GET/PATCH /v1/admin/feedbacks`（feedbacks 管理闭环已完成）。
新增契约明细见 `API_CONTRACT.md` §3「管理端」，摘要：

| 端点 | 说明 |
|---|---|
| `GET /v1/admin/letters` | status / delivery_mode / owner=seed\|user 筛选，limit+cursor 分页 → `Page[AdminLetterSummary]` |
| `GET /v1/admin/letters/{id}` | 全量 blocks + meta + 计数（含非 public，访问控制仅 admin JWT） |
| `PATCH /v1/admin/letters/{id}/status` | `{status, note?}`，按下方状态机流转；非法流转 409 `invalid_transition` |
| `GET /v1/admin/reports` | status 筛选（默认 open），JOIN 涉事信摘要 |
| `PATCH /v1/admin/reports/{id}` | `{status: dismissed\|actioned, admin_note?}`；置已处理回写 handled_at |
| `GET /v1/admin/stats` | 概览聚合：信件状态分布 / 用户数 / 7 日新增 / 池健康 / 待办数 |
| `GET /v1/admin/seed-letters` | 种子信列表（owner IS NULL） |
| `POST /v1/admin/seed-letters` | 新建种子信：复用 letter_service 校验（blocks 1–20、照片 ≤3、文字 ≤800），owner=NULL、status=public 直接入池（运营自己就是审核者，与 seed_letters.py 同口径） |
| `PATCH /v1/admin/seed-letters/{id}` | 编辑 blocks / place_label / weather / delivery_mode；仅限 owner IS NULL 的信，否则 403 `seed_letter_only` |

**信件状态机**（管理端视角）：

```
pending  → public | rejected          （审核裁决）
public   ↔ taken_down                 （下架 / 恢复；下架与作者下架同语义）
rejected → public                     （赦免，UI 二次确认）
```

不在表内的流转一律 409。`deleted_at`（作者「不再显示」）与管理端状态独立：
作者隐藏的信仍在管理端可见可处置，但读者侧口径不变。

**鉴权与迁移**：

- `uploads` 放宽为 user 或 admin JWT 均可（控制台传图）。
- 迁移 1 个（`make revision`）：`reports` 表补 `status`（open/dismissed/actioned，
  默认 open）+ `admin_note` + `handled_at` + `(status, created_at)` 索引，
  完全镜像 feedbacks 模式。
- 角色强制：新增 `require_role("admin")` 依赖，挂所有管理端写端点。

## 4. 前端工程结构（apps/admin/lib/）

```
lib/
  core/            admin ApiClient（401 踢登录）、sessionStorage 会话、
                   go_router 路由与登录守卫、工作台壳（导航/角标）
  features/
    dashboard/     概览（stats 消费）
    review/        审核队列 + 审核页（双栏骨架）
    letters/       信件管理（筛选/下架/恢复/赦免）
    reports/       举报处理
    feedback/      反馈管理
    seed/          种子信件管理（列表/新建/编辑 + 实时预览）
  shared/          双栏骨架、状态徽标、两段式确认弹层、AdminLetterView mapper
```

- 状态管理与主 App 同规：Riverpod + 四相控制器（loading/ready/empty/error）骨架。
- API base 指向本机 `services/api`；开发 `flutter run -d chrome`。
- 测试：controller/单元测试 + MockApiAdapter；E2E 用 chrome 手动走查（见 A2 验收）。

## 5. 里程碑（ROADMAP「A 系列」）

| 阶段 | 内容 | 量级 |
|---|---|---|
| A0 | 契约 + 后端补齐：上表 9 个端点、reports 迁移、require_role、uploads 放宽、db 测试；`make openapi` 同步 openapi.json | 1–1.5 天 |
| A1 | 控制台骨架 + 登录 + 概览 + 审核队列 + 信件管理 | 1.5 天 |
| A2 | 举报处理 + 反馈管理 + 种子信件管理（含编辑实时预览） | 1–1.5 天 |

**J4 联调节点（验收口径）**：

1. 造一封 pending 信 → 控制台审核通过 → App 端可读该信
2. App 端举报 → 控制台下架 → 读者侧 404、举报标记 actioned
3. 控制台新建种子信（drift）→ App 漂流可抽到
4. viewer 账号登录 → 写操作全部 403

## 6. 明确不做（v1）

- 种子信硬删除——用下架/恢复软管理，不破坏回信链与计数红线
- admin 账号管理 UI——继续 `scripts/create_admin.py`
- 操作审计表、批量审核、全文搜索（只做筛选 + cursor 分页）
- 推送/告警、多语言、移动端适配（桌面浏览器优先）

## 7. 待决

- 种子信编辑是否允许改 `theme_id/theme_skin`：默认**不允许**（永久绑定红线，
  新建时选定后不可改）；如运营确需，另立裁决。
- 审核驳回是否必填理由：v1 不必填（rejected 无通知机制），若未来要回执再加。
