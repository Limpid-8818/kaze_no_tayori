# 风信 · 开发环境说明

> 本机环境事实见根 `CLAUDE.md` §5。本文只讲怎么把环境跑起来、以及踩到坑时怎么办。

---

## 1. 前置工具

| 工具 | 版本 | 说明 |
|---|---|---|
| Flutter | 3.47.0+ | 含 Dart 3.13。`flutter doctor -v` 自查 |
| uv | 0.9.18+ | Python 包与虚拟环境管理，不用 pip/conda |
| GNU Make | 3.81+ | 本机在 `D:\ProgramFiles\GnuWin32\bin\make`，在 **git bash** 里跑 |
| Git | 2.49+ | |

**不需要** Docker（数据库在云端）。**不需要** Chrome（Web 用 Edge）。

---

## 2. 首次启动

```bash
cd /d/CodeRepository/misc/kazenotayori
cp .env.example .env      # 填写：见第 3 节
make bootstrap            # 自检 + uv sync + flutter pub get + 装 git hook
make api                  # → http://localhost:8000/docs
make app                  # → Edge 打开 App
```

后端不连数据库也能起（`/health` 只报进程存活）。要建表才需要数据库。

---

## 3. `.env` 怎么填

从 `.env.example` 复制后，按需要程度分三档：

**必填（否则无法建表/读写数据）**
- `DATABASE_URL` / `DATABASE_URL_SYNC` —— 比赛云服务器的 PostgreSQL 连接串。两条指向同一个库，前者用 asyncpg（运行时），后者用 psycopg（Alembic 迁移）。
- `DB_SCHEMA` —— **改成自己的名字**，如 `dev_yukai`。多人共用一台云库，靠 schema 隔离，见第 5 节。
- `JWT_SECRET` —— 随便一串长随机字符即可。

**可留空（对应功能自动降级，核心循环不受影响）**
- `FEATURE_AI` + `OPENAI_*` —— 关掉则写信流没有 AI 润色与短诗，纯手动。
- `FEATURE_MODERATION` —— 关掉则新信一律停在 `pending`（**不是** public），靠 `make seed` 或后续控制台放行。
- `FEATURE_WEATHER` + `WEATHER_API_KEY` —— 关掉则落点不带天气。
- `FEATURE_GEOCODE` + `AMAP_KEY` —— 关掉则地点名靠用户手填。
- `S3_*` —— `STORAGE_BACKEND=local` 时不需要，图片写服务器本地磁盘。

**前端用**
- `API_BASE_URL` —— `make app` 会通过 `--dart-define` 注入。真机调试见第 6 节。

---

## 4. 数据库初始化（需要云服务器就绪）

一次性准备（需超级权限，只做一次）：

```sql
CREATE EXTENSION IF NOT EXISTS postgis;   -- 装在 public，各 schema 共用其函数
CREATE SCHEMA IF NOT EXISTS dev_yukai;    -- 每人一个
```

然后建表：

```bash
make revision m="初始化信件与账户实体"   # 生成迁移
# >>> 人工审阅生成的迁移文件 <<<
make migrate                              # 应用
make seed                                 # 灌种子信（解决漂流池冷启动）
```

审阅迁移时重点看两处（GeoAlchemy2 已知坑）：
1. **空间索引没被重复创建** —— `create_geospatial_table` 建表时已自动带上 GiST 索引，若下面又出现一条 `create_index(... postgresql_using='gist')` 就删掉那条。
2. **`CREATE EXTENSION postgis` 在首个迁移置顶**。

---

## 5. 共享云数据库的纪律

一台远程 PG 被所有人和所有 Agent 共用，很容易互相踩。规则：

- **每人一个 schema**：`.env` 里 `DB_SCHEMA=dev_<yourname>`，连接时设 `search_path`。测试用 `test_<yourname>`。
- **改 schema 前先 `git pull`**，再 `make revision`。禁止两人同时生成迁移，否则 revision 链会分叉。
- 每个 schema 有自己的 `alembic_version` 表，互不影响。
- **不要在共享库上跑全库 `DROP`/`TRUNCATE`**；要清数据就清自己的 schema。
- 需要真 PostGIS 的测试标记 `@pytest.mark.db`，`make check` 默认跳过，`make check-db` 才跑。这样离线也能开发。

---

## 6. 常见故障

**`make` 报 `command not found`**
在 git bash 里跑，不是 PowerShell。确认 `D:\ProgramFiles\GnuWin32\bin` 在 PATH 里。

**`make help` 输出乱码**
Windows 控制台默认 GBK 代码页。这也是为什么所有终端输出都写成英文——如果你新增 `@echo`，请也用英文。

**`flutter run -d chrome` 报找不到 Chrome**
本机没装 Chrome。用 `make app`（走 `-d edge`）。

**真机调试时 App 连不上后端**
`API_BASE_URL` 不能用 `localhost`（那是手机自己）。改成电脑的局域网 IP：
```bash
make app-android API_BASE_URL=http://192.168.x.x:8000
```
并确认后端以 `--host 0.0.0.0` 起（Makefile 已如此）、防火墙放行 8000。

**Android 构建失败**
仓库刻意放在纯 ASCII 路径（`D:\CodeRepository\misc\kazenotayori`）——中文路径下 Gradle/NDK 有已知构建失败风险。**不要把仓库移回含中文的目录。**

**`flutter analyze` 报找不到 `*.g.dart` / `*.freezed.dart`**
生成物不入库。跑 `make gen`。

**改了 freezed / riverpod 注解后行为没变**
同样是 `make gen`。开发期可用 `dart run build_runner watch`。

**`uv run` 报缺包**
`cd services/api && uv sync`。不要用 pip 装。

---

## 7. 提交前

```bash
make check     # ruff + mypy + pytest(跳 db) + flutter analyze + flutter test
```

pre-commit hook 会拦密钥文件、跑 ruff 与 dart format。实在跑不动时 `git commit --no-verify` 逃生——比赛期间不让工具链阻塞进度，但别养成习惯。
