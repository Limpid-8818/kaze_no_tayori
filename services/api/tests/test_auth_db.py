"""设备认证（需真实数据库，@pytest.mark.db）。

共享云库纪律：测试自造自清，结束只删自己插入的 device_id。
"""

import uuid

import pytest
from sqlalchemy import delete, func, select

from app.core.security import decode_access_token
from app.models.user import User

pytestmark = pytest.mark.db


async def _cleanup(session, device_id: str) -> None:  # type: ignore[no-untyped-def]
    await session.execute(delete(User).where(User.device_id == device_id))
    await session.commit()


async def test_device_auth_returns_jwt(db_client, db_session):  # type: ignore[no-untyped-def]
    device_id = f"test-{uuid.uuid4().hex[:20]}"
    resp = await db_client.post("/v1/auth/device", json={"device_id": device_id})
    assert resp.status_code == 200
    body = resp.json()
    assert body["token_type"] == "bearer"
    # JWT 能被自己的密钥解开，sub 即返回的 user_id
    assert decode_access_token(body["access_token"]) == uuid.UUID(str(body["user_id"]))
    await _cleanup(db_session, device_id)


async def test_device_auth_idempotent(db_client, db_session):  # type: ignore[no-untyped-def]
    device_id = f"test-{uuid.uuid4().hex[:20]}"
    resp1 = await db_client.post("/v1/auth/device", json={"device_id": device_id})
    resp2 = await db_client.post("/v1/auth/device", json={"device_id": device_id})
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
