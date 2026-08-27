# 风信 · 开发环境说明

> 本机环境事实见根 `CLAUDE.md` §5。本文只讲怎么把环境跑起来、以及踩到坑时怎么办。

---

## 1. 前置工具

| 工具 | 版本 | 说明 |
|---|---|---|
| Flutter | 3.47.0+ | 含 Dart 3.13。`flutter doctor -v` 自查 |
| uv | 0.9.18+ | Python 包与虚拟环境管理，不用 pip/conda |
| GNU Make | 3.81+ | 统一通过仓库根目录的 `Makefile` 执行常用命令 |
| Git | 2.49+ | |
| Docker + Compose v2 | 可选 | 推荐用于运行本机 PostGIS；API 与 App 仍在宿主机运行 |
| Xcode + CocoaPods | 仅 iOS | `flutter doctor -v` 必须显示 Xcode 可用；真机还需要 Apple 开发签名 |

本机有 Docker 时，推荐只用它运行 PostGIS，避免依赖共享云数据库。Web 调试设备由 `make app` 自动选择：Windows 优先 Edge，其他平台优先 Chrome；也可用 `APP_DEVICE` 覆盖。

---

## 2. 首次启动

```bash
cp .env.example .env      # 填写：见第 3 节
make bootstrap            # 自检 + uv sync + flutter pub get + 装 git hook
make db-up                # Docker 启动本机 PostGIS
make migrate              # 应用迁移
make seed                 # 灌入本地开发种子数据
make api                  # → http://localhost:8000/docs
make app                  # → 浏览器打开 App
# macOS：flutter devices 取得设备 ID 后
make app-ios IOS_DEVICE=<id>
```

后端不连数据库也能启动（`/health` 只表示进程存活），但业务接口和 `/health/db` 需要数据库。PostGIS 数据保存在 Docker volume 中，`make db-stop` 不会删除数据。

---

## 3. `.env` 怎么填

从 `.env.example` 复制后，按需要程度分三档：

**必填（否则无法建表/读写数据）**

- `POSTGRES_USER` / `POSTGRES_PASSWORD` —— 本机 Docker 数据库账号；密码使用随机长字符串，并同步更新两条数据库连接串（特殊字符需要 URL 编码）。
- `DATABASE_URL` / `DATABASE_URL_SYNC` —— 两条指向同一个数据库，前者用 asyncpg（运行时），后者用 psycopg（Alembic 迁移）。本机默认连接 `127.0.0.1:5432`，也可替换为远程 PostgreSQL。
- `DB_SCHEMA` —— **改成自己的名字**，如 `dev_yukai`。即使使用本机数据库也保留独立 schema，避免迁移行为与共享环境不一致。
- `JWT_SECRET` —— 使用随机长字符串。

**可留空（对应功能自动降级，核心循环不受影响）**

- `FEATURE_AI` + `OPENAI_*` —— 关掉则写信流没有 AI 润色与短诗，纯手动。
- `FEATURE_MODERATION` —— 关掉则新信一律停在 `pending`（**不是** public），靠 `make seed` 或后续控制台放行。
- `FEATURE_WEATHER` + `WEATHER_API_KEY` —— 关掉则落点不带天气。
- `FEATURE_GEOCODE` + `AMAP_KEY` —— 关掉则地点名靠用户手填。
- `S3_*` —— `STORAGE_BACKEND=local` 时不需要，图片写服务器本地磁盘。

**前端用**

- `API_BASE_URL` —— `make app` 会通过 `--dart-define` 注入。真机调试见第 6 节。

---

## 4. 数据库初始化

本机 Docker 推荐直接运行：

```bash
make db-up       # 创建或启动 PostGIS
make db-status   # 查看健康状态
make migrate     # 建 schema 并应用迁移
make seed        # 灌入种子数据
make db-stop     # 停止数据库，但保留 volume 数据
```

Apple Silicon 上官方 `postgis/postgis:17-3.5` 镜像通过 Docker Desktop 的 amd64 模拟运行，首次拉取或启动会稍慢。

如果改用共享云数据库，一次性准备（需超级权限，只做一次）：

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
安装 GNU Make 3.81+ 并确认它在 `PATH` 中。Windows 推荐在 git bash 中运行。

**`make help` 输出乱码**
Windows 控制台默认 GBK 代码页。这也是为什么所有终端输出都写成英文——如果你新增 `@echo`，请也用英文。

**`make app` 没选到正确浏览器**
先用 `flutter devices` 查看设备 ID，再显式运行 `make app APP_DEVICE=chrome` 或 `make app APP_DEVICE=edge`。

**iOS 怎么启动**
先打开 Simulator 或连接已信任并完成开发者签名的 iPhone，运行 `flutter devices` 取得设备 ID，再执行 `make app-ios IOS_DEVICE=<id>`。iOS 模拟器访问 Mac 后端可用 `API_BASE_URL=http://127.0.0.1:8000`；iPhone 真机必须改为 Mac 的局域网地址。

**真机调试时 App 连不上后端**
`API_BASE_URL` 不能用 `localhost`（那是手机自己）。改成电脑的局域网 IP：
```bash
make app-android API_BASE_URL=http://192.168.x.x:8000
# 或
make app-ios IOS_DEVICE=<id> API_BASE_URL=http://192.168.x.x:8000
```
并确认后端以 `--host 0.0.0.0` 起（Makefile 已如此）、防火墙放行 8000。Android 只在 debug manifest 放行明文 HTTP；iOS 只放行局域网资源，首次访问会出现“本地网络”系统授权。拒绝后需到系统设置重新开启。release 与公网 API 一律使用 HTTPS。

若 `STORAGE_BACKEND=local`，后端的 `PUBLIC_BASE_URL` 也必须设成设备可访问的局域网地址；否则 API 虽可访问，返回的图片仍会指向手机自己的 `localhost`。演示环境优先使用 HTTPS API + 对象存储公网 URL。

**Web 定位不弹或始终失败**
浏览器 Geolocation 需要 secure context。`localhost` 可用于本机调试；通过局域网 IP 给其他设备打开 Web 时必须使用 HTTPS。权限网关在 Web 使用插件支持的 `location` 权限，不使用移动端专属的 `locationWhenInUse`。

**Android 构建失败**
仓库刻意放在纯 ASCII 路径（`D:\CodeRepository\misc\kazenotayori`）——中文路径下 Gradle/NDK 有已知构建失败风险。**不要把仓库移回含中文的目录。**

**`flutter analyze` 报找不到 `*.g.dart` / `*.freezed.dart`**
生成物不入库。跑 `make gen`。

**改了 freezed / riverpod 注解后行为没变**
同样是 `make gen`。开发期可用 `dart run build_runner watch`。

**`uv run` 报缺包**
`cd services/api && uv sync --frozen`。不要用 pip 装；需要增删依赖时使用 `uv add` / `uv remove`，由 uv 同步更新 `pyproject.toml` 与 `uv.lock`。

---

## 6a. Android 模拟器 E2E 排障（2026-08 实测）

用 adb/MCP 脚本化操作模拟器做端到端验证时的坑，全部在本机（Git Bash + API 36 模拟器）踩过：

**`adb shell input text` 不支持中文**（直接 NPE）。Gboard 处于中文模式时，纯字母还会被当成拼音组合，落在输入框里的是候选词而非原文。绕法：输入内容带数字/大写（如 `Kaze9`）可阻止组合；需要真中文时装 ADBKeyboard（`ime set com.android.adbkeyboard/.AdbIME` 后 `am broadcast -a ADB_INPUT_TEXT --es msg …`，注意 Windows shell 传中文需先把命令写进 UTF-8 文件 push 到设备再 `sh` 执行）。

**软键盘开着时点 image_picker 的入口无反应**：IME 关闭动画超时会挡住 picker Activity 的启动（logcat 可见 `ImeTracker … STATUS_TIMEOUT`）。先收起键盘（点空白处/BACK 一次）再点选图入口。产品代码后续可在唤起 picker 前 `unfocus()` 规避。

**`adb shell uiautomator dump` 看不到 Flutter 内容**：Flutter 语义树默认不进系统无障碍视图。用 android-emulator MCP 的 `android_ui_describe` / `android_ui_resolve`（能拿到 Flutter Semantics 的文本与坐标）；坐标取元素 bounds 的中心点再 `input tap`。

**Git Bash 下 adb 远端路径被转义**：`/sdcard/...` 会被展开成本地 Git 路径。远端路径写双斜杠 `//sdcard/...`，或 `MSYS_NO_PATHCONV=1`。

**`adb exec-out screencap -p` 经 Git Bash 重定向会得到坏 PNG**（CRLF 转换）。用 MCP 的 screenshot 工具，或 `adb shell screencap -p //sdcard/x.png` 再 `pull`。

**模拟器定位**：`adb emu geo fix <lon> <lat>`（注意经度在前），设完 App 内 LocationController 直接可用。

**杀进程后验证**：`am force-stop <pkg>` 后 `am start -W -n <pkg>/.MainActivity`，`LaunchState: COLD` 确认是真冷启。

---

## 7. 提交前

```bash
make check     # ruff + mypy + pytest(跳 db) + flutter analyze + flutter test
```

pre-commit hook 会拦密钥文件、跑 ruff 与 dart format。实在跑不动时 `git commit --no-verify` 逃生——比赛期间不让工具链阻塞进度，但别养成习惯。
