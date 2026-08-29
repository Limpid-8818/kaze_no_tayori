"""管理端种子信件管理与统计概览（需真实数据库，@pytest.mark.db）。

种子信 = owner IS NULL 且直接 public 入池。自造自清纪律同 test_feedback_db。
"""

import uuid

import pytest
from fastapi import status
from httpx import AsyncClient
from sqlalchemy import delete

from app.core.security import hash_password
from app.models.letter import Letter
from app.models.report import AdminAccount
from app.models.user import User

pytestmark = pytest.mark.db

_ADMIN_USERNAME = "test-seed-admin"
_VIEWER_USERNAME = "test-seed-viewer"

_SEED_BODY = {
    "blocks": [{"type": "text", "text": "种子信：今天风很轻"}],
    "delivery_mode": "drift",
    "place_label": "测试 · 种子镇",
}


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


async def _make_user(db_client: AsyncClient) -> tuple[str, str]:
    resp = await db_client.post(
        "/v1/auth/device", json={"device_id": f"test-{uuid.uuid4().hex[:20]}"}
    )
    assert resp.status_code == 200
    return resp.json()["access_token"], resp.json()["user_id"]


async def _make_account(db_session, username: str, role: str) -> None:  # type: ignore[no-untyped-def]
    db_session.add(
        AdminAccount(
            username=username,
            password_hash=hash_password("test-password-123"),
            role=role,
        )
    )
    await db_session.commit()


async def _login(db_client: AsyncClient, username: str) -> str:
    resp = await db_client.post(
        "/v1/admin/login",
        json={"username": username, "password": "test-password-123"},
    )
    assert resp.status_code == status.HTTP_200_OK
    return resp.json()["access_token"]


async def _cleanup(db_session, user_id: str) -> None:  # type: ignore[no-untyped-def]
    # 种子信 owner 为 NULL，按 place_label 前缀守卫删（B6 同款 test_ 守卫思路）
    await db_session.execute(delete(Letter).where(Letter.owner_user_id == uuid.UUID(user_id)))
    await db_session.execute(delete(Letter).where(Letter.place_label == "测试 · 种子镇"))
    await db_session.execute(delete(User).where(User.id == uuid.UUID(user_id)))
    await db_session.execute(
        delete(AdminAccount).where(AdminAccount.username.in_([_ADMIN_USERNAME, _VIEWER_USERNAME]))
    )
    await db_session.commit()


async def test_seed_letter_create_edit_pool(db_client, db_session) -> None:  # type: ignore[no-untyped-def]
    """新建种子信 → owner NULL/public → 用户 drift 可抽到 → 编辑生效。"""
    token, user_id = await _make_user(db_client)
    await _make_account(db_session, _ADMIN_USERNAME, "admin")
    admin_token = await _login(db_client, _ADMIN_USERNAME)

    # 新建：201，owner_user_id null、status public
    resp = await db_client.post(
        "/v1/admin/seed-letters", json=_SEED_BODY, headers=_auth(admin_token)
    )
    assert resp.status_code == status.HTTP_201_CREATED
    body = resp.json()
    letter_id = body["id"]
    assert body["owner_user_id"] is None
    assert body["status"] == "public"
    assert body["delivery_mode"] == "drift"

    # 入池：用户 drift 能抽到这封种子信
    resp = await db_client.get("/v1/drift/next", headers=_auth(token))
    assert resp.status_code == status.HTTP_200_OK
    assert resp.json()["id"] == letter_id

    # 列表在 seed-letters 里
    resp = await db_client.get("/v1/admin/seed-letters", headers=_auth(admin_token))
    assert letter_id in [i["id"] for i in resp.json()["items"]]

    # 编辑：改文案与落点；theme 不可传（extra=forbid → 422）
    resp = await db_client.patch(
        f"/v1/admin/seed-letters/{letter_id}",
        json={
            "blocks": [{"type": "text", "text": "种子信：改过了"}],
            "delivery_mode": "stay",
            "lat": 24.48,
            "lon": 118.08,
            "place_label": "测试 · 种子镇",
        },
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_200_OK
    body = resp.json()
    assert body["blocks"][0]["text"] == "种子信：改过了"
    assert body["delivery_mode"] == "stay"
    assert body["lat"] == 24.48

    resp = await db_client.patch(
        f"/v1/admin/seed-letters/{letter_id}",
        json={
            "blocks": [{"type": "text", "text": "x"}],
            "delivery_mode": "drift",
            "theme_id": "natsu",
        },
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

    # stay 缺坐标 → 400
    resp = await db_client.patch(
        f"/v1/admin/seed-letters/{letter_id}",
        json={
            "blocks": [{"type": "text", "text": "x"}],
            "delivery_mode": "stay",
        },
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_400_BAD_REQUEST

    # 下架后可恢复（走信件状态机）
    resp = await db_client.patch(
        f"/v1/admin/letters/{letter_id}/status",
        json={"status": "taken_down"},
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_200_OK

    await _cleanup(db_session, user_id)


async def test_seed_letter_guards(db_client, db_session, moderation_on) -> None:  # type: ignore[no-untyped-def]
    """有主信不可走种子信编辑通道（403 seed_letter_only）；viewer 写 403。"""
    token, user_id = await _make_user(db_client)
    resp = await db_client.post(
        "/v1/letters",
        json={"blocks": [{"type": "text", "text": "有主信"}], "delivery_mode": "drift"},
        headers=_auth(token),
    )
    letter_id = resp.json()["id"]

    await _make_account(db_session, _ADMIN_USERNAME, "admin")
    await _make_account(db_session, _VIEWER_USERNAME, "viewer")
    admin_token = await _login(db_client, _ADMIN_USERNAME)
    viewer_token = await _login(db_client, _VIEWER_USERNAME)

    resp = await db_client.patch(
        f"/v1/admin/seed-letters/{letter_id}",
        json={"blocks": [{"type": "text", "text": "劫持"}], "delivery_mode": "drift"},
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_403_FORBIDDEN
    assert resp.json()["error"]["code"] == "seed_letter_only"

    # viewer：新建种子信也 403
    resp = await db_client.post(
        "/v1/admin/seed-letters", json=_SEED_BODY, headers=_auth(viewer_token)
    )
    assert resp.status_code == status.HTTP_403_FORBIDDEN

    await _cleanup(db_session, user_id)


async def test_admin_stats_shape(db_client, db_session) -> None:  # type: ignore[no-untyped-def]
    """stats 聚合形状：状态分布 / 池健康 / 待办三数彼此一致。"""
    token, user_id = await _make_user(db_client)
    resp = await db_client.post("/v1/letters", json=_SEED_BODY, headers=_auth(token))
    letter_id = resp.json()["id"]  # pending

    await _make_account(db_session, _ADMIN_USERNAME, "admin")
    admin_token = await _login(db_client, _ADMIN_USERNAME)

    resp = await db_client.get("/v1/admin/stats", headers=_auth(admin_token))
    assert resp.status_code == status.HTTP_200_OK
    body = resp.json()
    assert body["letters_by_status"].get("pending", 0) >= 1
    assert body["users_total"] >= 1
    assert body["letters_7d"] >= 1
    assert body["letters_30d"] >= body["letters_7d"]
    assert set(body["pool"]) == {"drift_available", "stay_active"}
    assert body["todo"]["pending_letters"] >= 1
    assert set(body["todo"]) == {"pending_letters", "open_reports", "open_feedbacks"}

    await _cleanup(db_session, user_id)
    # pending 信不进池，stats 验证完即可删
    await db_session.execute(delete(Letter).where(Letter.id == uuid.UUID(letter_id)))
    await db_session.commit()


async def test_admin_token_can_upload(db_client, db_session) -> None:  # type: ignore[no-untyped-def]
    """admin JWT 打 uploads：能过身份关（坏 content-type 422 而非 401）。"""
    await _make_account(db_session, _ADMIN_USERNAME, "admin")
    admin_token = await _login(db_client, _ADMIN_USERNAME)

    resp = await db_client.post(
        "/v1/uploads/images",
        files={"file": ("x.txt", b"not-an-image", "text/plain")},
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
    assert resp.json()["error"]["code"] == "unsupported_image_type"

    # 对照：无 token 仍然 401
    resp = await db_client.post(
        "/v1/uploads/images",
        files={"file": ("x.txt", b"not-an-image", "text/plain")},
    )
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED
