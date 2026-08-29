"""反馈链路（需真实数据库，@pytest.mark.db）。

共享云库纪律：自造自清，结束只删自己插的 user、feedback 与 admin 账号。
"""

import uuid

import pytest
from fastapi import status
from httpx import AsyncClient
from sqlalchemy import delete

from app.core.security import create_access_token, hash_password
from app.models.feedback import Feedback
from app.models.report import AdminAccount
from app.models.user import User

pytestmark = pytest.mark.db

_ADMIN_USERNAME = "test-feedback-admin"


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


async def _make_user(db_client: AsyncClient) -> tuple[str, str]:
    resp = await db_client.post(
        "/v1/auth/device", json={"device_id": f"test-{uuid.uuid4().hex[:20]}"}
    )
    assert resp.status_code == 200
    return resp.json()["access_token"], resp.json()["user_id"]


async def _make_admin(db_session) -> None:  # type: ignore[no-untyped-def]
    db_session.add(
        AdminAccount(
            username=_ADMIN_USERNAME,
            password_hash=hash_password("test-password-123"),
            role="admin",
        )
    )
    await db_session.commit()


async def _cleanup(db_session, user_id: str) -> None:  # type: ignore[no-untyped-def]
    await db_session.execute(delete(Feedback).where(Feedback.user_id == uuid.UUID(user_id)))
    await db_session.execute(delete(User).where(User.id == uuid.UUID(user_id)))
    await db_session.execute(delete(AdminAccount).where(AdminAccount.username == _ADMIN_USERNAME))
    await db_session.commit()


async def test_submit_feedback_persists(db_client, db_session) -> None:  # type: ignore[no-untyped-def]
    """提交反馈 → 201，落库默认 open，环境上下文一并保存。"""
    token, user_id = await _make_user(db_client)
    resp = await db_client.post(
        "/v1/feedback",
        json={
            "category": "bug",
            "content": "读信页图片偶尔不显示",
            "app_version": "1.2.0",
            "platform": "android",
        },
        headers=_auth(token),
    )
    assert resp.status_code == status.HTTP_201_CREATED
    body = resp.json()
    assert body["status"] == "open"
    assert body["category"] == "bug"

    row = await db_session.get(Feedback, uuid.UUID(body["id"]))
    assert row is not None
    assert row.user_id == uuid.UUID(user_id)
    assert row.app_version == "1.2.0"
    assert row.platform == "android"
    assert row.handled_at is None
    await _cleanup(db_session, user_id)


async def test_admin_feedback_full_flow(db_client, db_session) -> None:  # type: ignore[no-untyped-def]
    """admin 登录 → 列表 → PATCH 状态/备注 全链路；user token 冒用 admin 接口须 401。"""
    token, user_id = await _make_user(db_client)
    resp = await db_client.post(
        "/v1/feedback",
        json={"category": "suggestion", "content": "希望支持夜间模式"},
        headers=_auth(token),
    )
    assert resp.status_code == status.HTTP_201_CREATED
    feedback_id = resp.json()["id"]

    await _make_admin(db_session)

    # user token 冒用 admin 列表 → 401（typ 校验）
    resp = await db_client.get("/v1/admin/feedbacks", headers=_auth(token))
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED

    # 未登录 → 401
    resp = await db_client.get("/v1/admin/feedbacks")
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED

    # 登录拿 admin token
    resp = await db_client.post(
        "/v1/admin/login",
        json={"username": _ADMIN_USERNAME, "password": "test-password-123"},
    )
    assert resp.status_code == status.HTTP_200_OK
    admin_token = resp.json()["access_token"]

    # 错误密码 → 401
    resp = await db_client.post(
        "/v1/admin/login",
        json={"username": _ADMIN_USERNAME, "password": "no-such-password"},
    )
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED

    # 列表：能看到刚提交的反馈（含环境上下文）
    resp = await db_client.get(
        "/v1/admin/feedbacks",
        params={"category": "suggestion"},
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_200_OK
    items = resp.json()["items"]
    target = next(item for item in items if item["id"] == feedback_id)
    assert target["status"] == "open"
    assert target["content"] == "希望支持夜间模式"

    # PATCH：置 resolved + 写备注 → handled_at 回写
    resp = await db_client.patch(
        f"/v1/admin/feedbacks/{feedback_id}",
        json={"status": "resolved", "admin_note": "排期到下个迭代"},
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_200_OK
    body = resp.json()
    assert body["status"] == "resolved"
    assert body["admin_note"] == "排期到下个迭代"
    assert body["handled_at"] is not None

    # PATCH：回退 open → handled_at 清空，备注保留
    resp = await db_client.patch(
        f"/v1/admin/feedbacks/{feedback_id}",
        json={"status": "open"},
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_200_OK
    body = resp.json()
    assert body["handled_at"] is None
    assert body["admin_note"] == "排期到下个迭代"

    # PATCH：什么都不改 → 422
    resp = await db_client.patch(
        f"/v1/admin/feedbacks/{feedback_id}", json={}, headers=_auth(admin_token)
    )
    assert resp.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

    # PATCH 不存在的反馈 → 404
    resp = await db_client.patch(
        f"/v1/admin/feedbacks/{uuid.uuid4()}",
        json={"status": "resolved"},
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_404_NOT_FOUND

    await _cleanup(db_session, user_id)


async def test_admin_login_unknown_account_401(db_client) -> None:  # type: ignore[no-untyped-def]
    """不存在的账号登录 → 401（不区分账号不存在与密码错误）。"""
    resp = await db_client.post(
        "/v1/admin/login", json={"username": "no-such-admin", "password": "whatever-123"}
    )
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED


async def test_deleted_admin_account_token_invalidated(db_client, db_session) -> None:  # type: ignore[no-untyped-def]
    """token 有效但 admin 账号已被删 → 401（CurrentAdmin 复查账号存在性）。"""
    admin_id = uuid.uuid4()
    db_session.add(
        AdminAccount(
            id=admin_id,
            username="temp-admin-to-delete",
            password_hash=hash_password("password-123"),
            role="admin",
        )
    )
    await db_session.commit()
    token = create_access_token(admin_id)  # 普通签发器仅用于构造，typ 校验见离线测试
    from app.core.security import create_admin_token

    admin_token = create_admin_token(admin_id)

    resp = await db_client.get("/v1/admin/feedbacks", headers=_auth(admin_token))
    assert resp.status_code == status.HTTP_200_OK

    # 删账号后同一 token 立即失效
    await db_session.execute(delete(AdminAccount).where(AdminAccount.id == admin_id))
    await db_session.commit()
    resp = await db_client.get("/v1/admin/feedbacks", headers=_auth(admin_token))
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED

    # 收尾：确认普通 user 签发器造的 token 打 admin 接口也是 401
    resp = await db_client.get("/v1/admin/feedbacks", headers=_auth(token))
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED
