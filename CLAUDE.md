# 风信 Kaze no tayori · 全局规则

> 本文是本仓库所有开发者与 Agent 的**行为约束**。产品事实以 `docs/PRD.md` 为准（single source of truth），本文只讲「怎么做、不许怎么做」。
> 冲突时优先级：`docs/PRD.md` §7 红线 > 本文 > 各包局部 CLAUDE.md > 个人偏好。

---

## 1. 项目身份

- **产品名：风信 / Kaze no tayori（風の便り）**。这是对外唯一名称。
- `natsu_no_tegami`（夏の手紙）是**当前视觉方向的代号**，不是产品名，只用于设计系统包名。不要在 UI 文案、README、提交信息里把它当产品名用。
- 一句话定位：让旅行中陌生人的思绪匿名漂流、彼此接住的系统。信可随机漂向远方（Drift），也可埋在某地等后来者发掘（Stay）。
- 赛道：**制造一点意外**（反"更懂你"的算法）。这决定了一条技术倾向：**不要精准，要偶然**。任何让结果"更符合用户口味"的改动都与赛题相悖。
- 核心循环：`✍️ 创作 → 📮 留/投 → 🌍 旅行或埋藏 → 👤 拾取/发掘 → 📖 阅读 → ✦共鸣/📝回信 → 原作者得知（非私信）`

---

## 2. 红线：8 条不可违背的工程约束

这 8 条由 `docs/PRD.md` §7 逐条译成可 review 的工程语言。**违反其中任何一条的代码，无论多好用，都必须回退。**

1. **匿名铁律。** 任何返回给客户端的信件响应体不得含 `owner_user_id` 或任何作者标识（昵称/头像/主页/AnonID）。新增涉及信件的 endpoint 必须复用 `LetterPublic` schema，不许另造一个"顺便带上作者"的响应模型。读者不可达作者。
2. **不做社交度量。** 禁止新增 like / follow / feed / trending / rank / score / hot 语义的表、字段、endpoint、UI 组件。计数只有 5 个：`read_count / resonance_count / voice_count / reply_count / saved_count`。共鸣是"已被 N 个陌生人接住"，不是点赞。
3. **回信是独立作品，不是私信。** 回信是 `letters` 表里一条独立行，靠 `parent_letter_id` 溯源。禁止建立 DM / conversation / thread / message 表。原作者只收到一条 `Notification`，他不是回信的收件人。
4. **计数替代轨迹。** 不记录单信空间轨迹，不做跨信热度比较排序。列表排序只允许 `created_at` 或 `random()`。
5. **生命周期默认永驻。** `expire_at` 字段保留但恒为 NULL，不实现过期清理任务、不写定时删除。
6. **皮肤永久绑定单信。** `theme` 一旦写入不得批量 `UPDATE`，不做季节归档/自动迁移。新增主题只加皮肤包，不动历史数据。
7. **音乐是引用式。** `music_ref` 只有 `{album, song, lyrics}` 三个字符串。禁止新增 url / audio_url / 外链 / 上传音频字段。
8. **AI 是桥不是枪手，且一切外部依赖可降级。** 每个 `FEATURE_*` 开关关闭时，核心循环（写→漂→收→共鸣→再写）必须仍然跑通。**审核降级方向是 `pending`（待审不公开），绝不是 `public`** —— 机审失效时默认不公开，这条不许"为了 demo 顺畅"放宽。

> 自检口令：写完任何一个 endpoint，先问自己「这会不会让读者更容易知道作者是谁 / 让某封信比另一封更'热门' / 让推荐更准」。三个都否，才算合规。

---

## 3. 仓库导航：什么代码放哪

```
docs/          产品与契约文档。PRD.md 是事实来源，改实体/endpoint 必须同步 API_CONTRACT.md
services/api/  FastAPI 后端（唯一 Python 包）。业务逻辑在 app/services/，router 只做 HTTP 转换
apps/app/      Flutter 主应用。feature-first：一个功能一个目录
apps/admin/    运营控制台（P1，Flutter Web，尚无代码）。设计见 docs/ADMIN_CONSOLE.md，实施随 ROADMAP A 系列；P0 冷启动用 services/api/scripts/seed_letters.py
packages/      Dart 包。natsu_no_tegami = 设计系统（当前是空壳，见其 COPY_IN.md，禁止手改）
infra/         云端部署产物（docker-compose 等）。本地开发不跑它
scripts/       跨语言的仓库级脚本
```

放置规则：
- 后端业务逻辑 → `services/api/app/services/`，**不要写在 router 里**。
- 前端跨 feature 复用的视觉组件 → 上游设计系统仓库，或暂放 `apps/app/lib/app/widgets/` 并在 `packages/natsu_no_tegami/COPY_IN.md` 记一笔待上游化。**不要塞进某个 feature**。
- 前端网络调用 → 只经 `apps/app/lib/data/api/api_client.dart`，feature 里不许直接 new Dio。

---

## 4. 常用命令

一律走根目录 Makefile，不要手敲长命令（本机 make 在 `D:\ProgramFiles\GnuWin32\bin\make`）。

| 命令 | 作用 |
|---|---|
| `make bootstrap` | 环境自检 + 装依赖 + 装 git hook |
| `make api` | 起后端（reload） |
| `make app` | 起 App（Web，`-d edge`） |
| `make app-android` | 起 App（Android 设备） |
| `make gen` | Flutter 代码生成（freezed / riverpod） |
| `make revision m="..."` | Alembic autogenerate |
| `make migrate` | Alembic upgrade head |
| `make seed` | 灌种子信（冷启动） |
| `make check` | ruff + mypy + pytest（跳 db）+ flutter analyze + flutter test |
| `make check-db` | 跑需要真 PostGIS 的测试 |
| `make openapi` | 导出 `docs/openapi.json` |
| `make sync-ds` | 从上游同步设计系统 |

---

## 5. 环境事实（别重新探测，已于 2026-08-20 实测）

- Flutter 3.47.0 / Dart 3.13.0；**Android SDK 36.0.0 已装**；Java 21。
- 可用设备：`edge`（web）、`windows`（desktop）。
- **本机无 Chrome** → Web 一律 `flutter run -d edge`，不要用 `-d chrome`。
- **本机无 Docker** → `infra/docker-compose.yml` 只是云端部署产物，不要试图本地 `docker compose up`。
- **本机无 `gh` CLI**，仓库无 remote、无 CI。质量关卡靠 `make check` + git hook。
- 数据库在**比赛云服务器**上，本地开发直连远程 PostGIS。
- Python 用 uv 托管的 3.13（不要用系统 3.12）；uv 0.9.18。
- VS C++ 组件缺失 → 只影响 Windows desktop 构建，与 P0 无关，不用管。
- 仓库路径为纯 ASCII（`D:\CodeRepository\misc\kazenotayori`），这是刻意的：中文路径下 Gradle/NDK 有构建失败风险。**不要把仓库移回含中文的路径。**

---

## 6. 数据库纪律（共享云 DB，容易互相踩）

所有人/所有 Agent 共用一台远程 PG，因此：

- 每人一个 schema：`.env` 里 `DB_SCHEMA=dev_<yourname>`，连接时设 `search_path`。PostGIS extension 只装在 `public`，各 schema 共用其函数。
- **改 schema 前先 `git pull`**，再 `make revision`。禁止两人同时生成迁移。
- Alembic autogenerate 的产物**必须人工审阅**才能提交，重点看两处：① 空间索引有没有被重复创建（GeoAlchemy2 已知坑）② `CREATE EXTENSION` 是否在首个迁移置顶。
- 不要在共享库上跑 `drop`/`truncate` 全表操作；需要清数据就清自己 schema。
- 需要真 PostGIS 的测试用独立 schema（`test_<name>`），并标记 `@pytest.mark.db`。

---

## 7. 代码规范

**Python**：ruff（lint + format）+ mypy。函数必须有类型标注。禁止裸 `except:`。所有外部调用（LLM/天气/存储/逆地理）必须有超时与降级分支。

**Dart**：flutter_lints + riverpod_lint + `dart format`。
- **禁止字面量颜色/字号/间距**，一律走 `Theme.of(context)` 或设计系统 token。这样上游组件库拷入后不需要改 feature 代码。
- **画布（Ardot 设计稿）定布局与结构，组件库定信件内容物**：两者冲突时以 `natsu_no_tegami`
  现有组件为准（信纸质感、排版节奏、photo/stamp/seal 的归属都是组件库说了算），偏差在代码注释里
  记录；结构性尺寸（卡片高、行高、圆角）收进 `theme.dart` 的 `Kaze*Dims`，不散落 feature。
- `packages/natsu_no_tegami` 只许被 `apps/app/lib/app/theme.dart` import（内容物组件
  `components/letters/`、`components/` 除外，feature 可直接用；手写体 hw* 令牌沿 about_screen 先例）。
- 改了 freezed / riverpod 注解必须跑 `make gen`。
- feature 之间不得互相 import。

**生成物不入库**：`*.g.dart` / `*.freezed.dart` 已在 .gitignore，靠 `make gen` 重建。`uv.lock` 与 `pubspec.lock` 入库。

---

## 8. 提交与分支

- **Conventional Commits + 中文描述**：`feat: 就地发掘接口与 ST_DWithin 查询`、`fix: 漂流抽取漏掉已读过滤`、`chore: 初始化 monorepo 骨架`。类型用 `feat/fix/chore/refactor/docs/test`。
- **trunk-based**：直接提交 `main`。只在做可能破坏骨架的大改动时开短命分支。1–2 人 10 天，PR 流程开销大于收益。
- 只有用户明确要求时才提交；不要自动 commit。
- 绝不提交 `.env`（git hook 会拦，但别依赖它）。

---

## 9. 文档同步义务

改代码时**同一次提交内**同步文档，不要留给"以后补"：

- 新增/修改 endpoint → 更新 `docs/API_CONTRACT.md`，并跑 `make openapi` 固化 `docs/openapi.json`（契约漂移时 git diff 立刻可见）。
- 新增/修改实体或字段 → 更新 `docs/API_CONTRACT.md` 的数据模型段。若与 `docs/PRD.md` §9 有偏差，必须在 API_CONTRACT.md 里显式记录偏差原因（例：`letter_reads` 表是 PRD 未列但 6.3「未读过」需求必需的推导实体）。
- 改动模块边界 → 更新 `docs/ARCHITECTURE.md`。
- **不要修改 `docs/PRD.md` 与 `docs/设计叙事.md`**，它们是既定输入；有异议先与用户确认。

---

## 10. 交付优先级

`P0 = 初赛必须`、`P1 = 初赛争取`、`P2 = 二期/延后`，清单见 `docs/PRD.md` §6。

不确定该不该做某个功能时的判据：**它在 P0 清单里吗？它是 `docs/PRD.md` §12 明确"不做/延后"的吗？** §12 里的东西（AI 音乐生成、上传音频、外链、全局轨迹地图、社交/推荐 Feed/主页、即时聊天、排行榜）**一律不许实现，哪怕很容易**。

验收标准见 `docs/PRD.md` §11：端到端双路径（埋信→发掘→共鸣→回信→原作者收通知；投递→随机收到→导出图片）走通。
