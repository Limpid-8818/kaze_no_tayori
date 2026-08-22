"""pytest 公共 fixture。

不需要数据库的测试直接打 ASGI app（不起真实服务器）。
需要真 PostGIS 的测试标记 `@pytest.mark.db`，由 `make check-db` 单独跑——
这样本机离线/云库未就绪时，纯逻辑测试照样能跑。
"""

from collections.abc import AsyncGenerator

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.db import create_engine, get_session
from app.main import app


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession]:
    """DB 测试的独立引擎 + 覆盖 app 的 get_session 依赖。

    pytest 每个测试一个事件循环，模块级共享的 asyncpg 连接池跨循环复用会炸
    （Windows proactor 下尤甚），因此每个测试新建引擎并在 teardown dispose。
    """
    engine = create_engine()
    factory = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)

    async def _override() -> AsyncGenerator[AsyncSession]:
        async with factory() as session:
            try:
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
