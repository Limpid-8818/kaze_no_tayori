"""设备认证（需真实数据库，@pytest.mark.db）。

共享云库纪律：测试自造自清，结束只删自己插入的 device_id。

每个测试用独立引擎 + dependency_overrides：pytest 每个测试一个事件循环，
模块级共享的 asyncpg 连接池跨循环复用会炸（Windows proactor 下尤甚）。
"""

import uuid
from collections.abc import AsyncGenerator

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.db import create_engine, get_session
from app.main import app
from app.models.user import User

pytestmark = pytest.mark.db


@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession]:
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
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _cleanup(session: AsyncSession, device_id: str) -> None:
    await session.execute(delete(User).where(User.device_id == device_id))
    await session.commit()


async def test_device_auth_returns_jwt(client, db_session):  # type: ignore[no-untyped-def]
    device_id = f"test-{uuid.uuid4().hex[:20]}"
    resp = await client.post("/v1/auth/device", json={"device_id": device_id})
    assert resp.status_code == 200
    body = resp.json()
    assert body["token_type"] == "bearer"
    # JWT 能被自己的密钥解开，sub 即返回的 user_id
    from app.core.security import decode_access_token

    assert decode_access_token(body["access_token"]) == uuid.UUID(str(body["user_id"]))
    await _cleanup(db_session, device_id)


async def test_device_auth_idempotent(client, db_session):  # type: ignore[no-untyped-def]
    device_id = f"test-{uuid.uuid4().hex[:20]}"
    resp1 = await client.post("/v1/auth/device", json={"device_id": device_id})
    resp2 = await client.post("/v1/auth/device", json={"device_id": device_id})
    assert resp1.status_code == resp2.status_code == 200
    # 并发幂等：同一 device_id 两次绑定指向同一用户
    assert resp1.json()["user_id"] == resp2.json()["user_id"]

    count = await db_session.scalar(
        select(func.count()).select_from(User).where(User.device_id == device_id)
    )
    assert count == 1
    await _cleanup(db_session, device_id)


async def test_device_auth_validation(client):  # type: ignore[no-untyped-def]
    resp = await client.post("/v1/auth/device", json={"device_id": "short"})
    assert resp.status_code == 422
    body = resp.json()
    assert body["error"]["code"] == "validation_error"
