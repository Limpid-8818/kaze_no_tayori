"""pytest 公共 fixture。

不需要数据库的测试直接打 ASGI app（不起真实服务器）。
需要真 PostGIS 的测试标记 `@pytest.mark.db`，由 `make check-db` 单独跑——
这样本机离线/云库未就绪时，纯逻辑测试照样能跑。

数据库测试纪律（CLAUDE.md §6）：
- 开发环境用 `dev_<name>` schema
- 测试环境用独立的 `test_<name>` schema，与开发数据完全隔离
- 测试开始前自动创建 schema 并建表
- 测试结束后清理 schema，不留残留数据
"""

from collections.abc import AsyncGenerator

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import get_settings
from app.core.db import get_session
from app.main import app


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def moderation_on(monkeypatch: pytest.MonkeyPatch) -> None:
    """FEATURE_MODERATION=true + 空关键词表 → 新信直接 public（契约允许的开发路径）。"""
    monkeypatch.setattr(get_settings(), "feature_moderation", True)


@pytest.fixture
async def test_db_schema(monkeypatch: pytest.MonkeyPatch) -> AsyncGenerator[str]:
    """为当前测试创建独立的 `test_<NAME>` schema，并运行迁移。

    测试结束后自动清理（DROP SCHEMA ... CASCADE），确保与开发数据完全隔离。

    注意：Alembic 迁移文件硬编码了 schema="dev_limpid"，
    因此这里用 Base.metadata.create_all() 在 test schema 上直接建表。
    """
    # get_settings 有 lru_cache，必须先清掉，否则 monkeypatch 不生效
    get_settings.cache_clear()

    settings = get_settings()
    dev_schema = settings.db_schema
    # 从 dev_<name> 推导 test_<name>
    if dev_schema.startswith("dev_"):
        test_schema = "test_" + dev_schema[4:]
    else:
        test_schema = "test_" + dev_schema

    # 用同步引擎创建/清理 schema
    sync_url = settings.database_url_sync
    from sqlalchemy import create_engine as sync_create_engine

    sync_engine = sync_create_engine(sync_url, isolation_level="AUTOCOMMIT")

    with sync_engine.connect() as conn:
        # 清理旧测试 schema（如果存在）
        conn.execute(text(f'DROP SCHEMA IF EXISTS "{test_schema}" CASCADE'))
        # 创建新测试 schema
        conn.execute(text(f'CREATE SCHEMA "{test_schema}"'))
        conn.commit()

    # 临时覆盖 db_schema，让所有后续代码使用 test schema
    monkeypatch.setattr(settings, "db_schema", test_schema)
    # 同步 Base.metadata.schema，否则 ORM 仍写入旧 schema
    from app.models.base import set_schema

    set_schema(test_schema)

    # 用 Base.metadata.create_all 在 test schema 上创建所有表
    # （绕过 Alembic 迁移文件硬编码 schema="dev_limpid" 的问题）
    from app.models import Base

    async_engine = create_async_engine(
        settings.database_url,
        connect_args={"server_settings": {"search_path": f"{test_schema},public"}},
    )
    async with async_engine.connect() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await conn.commit()

    await async_engine.dispose()

    yield test_schema

    # 测试结束后清理
    with sync_engine.connect() as conn:
        conn.execute(text(f'DROP SCHEMA IF EXISTS "{test_schema}" CASCADE'))
        conn.commit()
    sync_engine.dispose()


@pytest.fixture
async def db_session(test_db_schema: str) -> AsyncGenerator[AsyncSession]:
    """DB 测试的独立引擎 + 覆盖 app 的 get_session 依赖。

    直接用传入的 test_db_schema 创建引擎，确保 search_path 正确。
    """
    # 直接用 test_db_schema 创建引擎，绕过 get_settings() 缓存
    from app.core.config import get_settings

    settings = get_settings()
    engine = create_async_engine(
        settings.database_url,
        connect_args={"server_settings": {"search_path": f"{test_db_schema},public"}},
    )
    factory = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)

    async def _override() -> AsyncGenerator[AsyncSession]:
        async with factory() as session:
            try:
                # 确保每个请求都在正确的 schema 下执行
                await session.execute(text(f'SET search_path TO "{test_db_schema}", public'))
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    app.dependency_overrides[get_session] = _override
    async with factory() as session:
        yield session
    app.dependency_overrides.pop(get_session, None)
    await engine.dispose()


@pytest.fixture
async def db_client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient]:
    """打 ASGI app 且走 db_session 独立引擎的 HTTP 客户端（@pytest.mark.db 用）。"""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
