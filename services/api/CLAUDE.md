# 后端局部规则（services/api）

> 全局红线见仓库根 `CLAUDE.md` §2，本文只讲后端技术约定。
> 接口契约见 `docs/API_CONTRACT.md`，模块职责见 `docs/ARCHITECTURE.md`。

## 分层纪律

```
api/v1/*.py   只做：解析请求 → 调 service → 转成 response schema
services/*.py 全部业务规则。接收 AsyncSession 参数，不感知 HTTP
models/*.py   只描述表结构，不含业务方法
schemas/*.py  Pydantic。LetterPublic 是匿名铁律的执行点
core/         配置、DB、JWT、依赖、错误
```

- **router 里不写业务逻辑，不直接写 SQL。** 三行以上的判断就该下沉到 service。
- **DB 访问只经 `get_session` 依赖**，不要自建 session（自检脚本例外，见 `api/v1/health.py` 的注释）。
- service 层抛 `core/errors.py` 里的 `AppError` 子类，**不要手写 `HTTPException`**——统一错误体靠全局 handler。

## 类型与检查

- 所有函数必须有类型标注（`disallow_untyped_defs`）。
- 提交前 `make check-py`（ruff format + ruff check + mypy + pytest）。
- 禁止裸 `except:`。宽 `except Exception` 只允许出现在**职责就是报告任何失败原因**的地方（如 `/health/db`、`scripts/check_db.py`），且必须写注释说明为什么。

## 外部依赖一律可降级（PRD §8.3）

每个 `FEATURE_*` 对应一个降级分支，且**降级不抛 500**：

| 模块 | 关闭/失败时 |
|---|---|
| `ai_service` | 抛 `FeatureDisabled`(503)，前端降级为纯手动写信 |
| `weather_service` | 返回 `None`，落点少个天气字段 |
| `geo_service` | 返回 `None`，地点名由用户手填 |
| `storage_service` | 降级为本地磁盘 |
| `moderation_service` | **返回 `PENDING`，绝不 `PUBLIC`** |

外部调用必须带超时。新增外部依赖时同步在 `.env.example` 加 `FEATURE_*` 开关。

`FeatureDisabled` 与 `ServiceUnavailable` 的区别：前者是「刻意关掉了」，后者是「本该可用但挂了」。

## 数据库

- 共享云库靠 per-developer schema 隔离，见 `docs/DEV_SETUP.md` §5。
- **改 schema 前先 `git pull`**，再 `make revision`。禁止两人同时生成迁移。
- **Alembic autogenerate 的产物必须人工审阅**，重点两处：
  1. 空间索引没被重复创建 —— `Geography` 列默认 `spatial_index=True`，建表时已自动带 GiST 索引，模型里**不要**再声明一次（见 `models/letter.py` 末尾注释）
  2. 首个迁移置顶 `op.execute("CREATE EXTENSION IF NOT EXISTS postgis")`
- `migrations/env.py` 的 GeoAlchemy2 三件套（`include_object` / `writer` / `render_item`）**不要删**，缺任一都会让 autogenerate 出错。
- **`alembic.ini` 必须保持纯 ASCII** —— configparser 用系统区域编码（本机 GBK）读它，中文注释会直接崩。中文说明写在 `env.py` 里。
- 新增模型必须在 `app/models/__init__.py` 登记，否则 autogenerate 发现不了。

## 测试

- 不需要 DB 的测试直接打 ASGI app（`tests/conftest.py` 的 `client` fixture）。
- 需要真 PostGIS 的测试标记 `@pytest.mark.db`，用独立 schema（`test_<name>`），`make check-db` 才跑。这样云库未就绪/离线时纯逻辑测试照跑。
- **`tests/test_anonymity.py` 是红线的机械守卫**：如果你因为它报错而来改它，先想清楚——那大概说明你正在往响应里加作者字段。改回 schema，不要改测试。

## 终端输出用英文

Windows 控制台默认 GBK 代码页，`print` 中文会乱码。`scripts/` 下的输出一律英文；注释和 docstring 保持中文。
