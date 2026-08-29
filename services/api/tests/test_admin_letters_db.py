"""管理端信件审核链路（需真实数据库，@pytest.mark.db）。

共享云库纪律：自造自清，结束只删自己插的 user、letter 与 admin 账号。
状态机口径见 docs/ADMIN_CONSOLE.md §3。
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

_ADMIN_USERNAME = "test-letters-admin"
_VIEWER_USERNAME = "test-letters-viewer"

_LETTER_BODY = {
    "blocks": [{"type": "text", "text": "风把海的味道带来了"}],
    "delivery_mode": "drift",
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
    await db_session.execute(delete(Letter).where(Letter.owner_user_id == uuid.UUID(user_id)))
    await db_session.execute(delete(User).where(User.id == uuid.UUID(user_id)))
    await db_session.execute(
        delete(AdminAccount).where(AdminAccount.username.in_([_ADMIN_USERNAME, _VIEWER_USERNAME]))
    )
    await db_session.commit()


async def test_admin_letter_review_flow(db_client, db_session) -> None:  # type: ignore[no-untyped-def]
    """造 pending 信 → 管理端通过 → 读者可读；非法流转 409；下架后读者 404。"""
    token, user_id = await _make_user(db_client)
    resp = await db_client.post("/v1/letters", json=_LETTER_BODY, headers=_auth(token))
    assert resp.status_code == status.HTTP_201_CREATED
    letter_id = resp.json()["id"]
    assert resp.json()["status"] == "pending"  # moderation 关闭 → pending

    await _make_account(db_session, _ADMIN_USERNAME, "admin")
    admin_token = await _login(db_client, _ADMIN_USERNAME)

    # 列表（status=pending 筛选）能看到这封信
    resp = await db_client.get(
        "/v1/admin/letters", params={"status": "pending"}, headers=_auth(admin_token)
    )
    assert resp.status_code == status.HTTP_200_OK
    summary = next(i for i in resp.json()["items"] if i["id"] == letter_id)
    assert summary["status"] == "pending"
    assert "海的味道" in summary["preview"]

    # 详情：全量 blocks + owner_user_id（仅管理端）
    resp = await db_client.get(f"/v1/admin/letters/{letter_id}", headers=_auth(admin_token))
    assert resp.status_code == status.HTTP_200_OK
    detail = resp.json()
    assert detail["owner_user_id"] == user_id
    assert detail["blocks"][0]["text"] == "风把海的味道带来了"

    # 非法流转：pending → taken_down 409
    resp = await db_client.patch(
        f"/v1/admin/letters/{letter_id}/status",
        json={"status": "taken_down"},
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_409_CONFLICT
    assert resp.json()["error"]["code"] == "invalid_transition"

    # 审核通过：pending → public，读者侧立即可读
    resp = await db_client.patch(
        f"/v1/admin/letters/{letter_id}/status",
        json={"status": "public"},
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_200_OK
    assert resp.json()["status"] == "public"
    resp = await db_client.get(f"/v1/letters/{letter_id}")
    assert resp.status_code == status.HTTP_200_OK

    # 表外流转：public → rejected 409（须先下架再赦免路径不含此向）
    resp = await db_client.patch(
        f"/v1/admin/letters/{letter_id}/status",
        json={"status": "rejected"},
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_409_CONFLICT

    # 下架 → 读者 404；恢复 → 读者 200
    resp = await db_client.patch(
        f"/v1/admin/letters/{letter_id}/status",
        json={"status": "taken_down"},
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_200_OK
    resp = await db_client.get(f"/v1/letters/{letter_id}")
    assert resp.status_code == status.HTTP_404_NOT_FOUND
    resp = await db_client.patch(
        f"/v1/admin/letters/{letter_id}/status",
        json={"status": "public"},
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_200_OK
    resp = await db_client.get(f"/v1/letters/{letter_id}")
    assert resp.status_code == status.HTTP_200_OK

    await _cleanup(db_session, user_id)


async def test_admin_letters_auth_guards(db_client, db_session) -> None:  # type: ignore[no-untyped-def]
    """无 token / user token 冒用 → 401；viewer 读 200 写 403。"""
    token, user_id = await _make_user(db_client)
    resp = await db_client.post("/v1/letters", json=_LETTER_BODY, headers=_auth(token))
    letter_id = resp.json()["id"]

    await _make_account(db_session, _ADMIN_USERNAME, "admin")
    await _make_account(db_session, _VIEWER_USERNAME, "viewer")
    await _login(db_client, _ADMIN_USERNAME)  # admin 登录链路顺带验证
    viewer_token = await _login(db_client, _VIEWER_USERNAME)

    resp = await db_client.get("/v1/admin/letters")
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED
    resp = await db_client.get("/v1/admin/letters", headers=_auth(token))
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED

    # viewer：读可以，写 403 admin_forbidden
    resp = await db_client.get("/v1/admin/letters", headers=_auth(viewer_token))
    assert resp.status_code == status.HTTP_200_OK
    resp = await db_client.patch(
        f"/v1/admin/letters/{letter_id}/status",
        json={"status": "public"},
        headers=_auth(viewer_token),
    )
    assert resp.status_code == status.HTTP_403_FORBIDDEN
    assert resp.json()["error"]["code"] == "admin_forbidden"

    # user token 冒用写端点也是 401（typ 校验先于角色）
    resp = await db_client.patch(
        f"/v1/admin/letters/{letter_id}/status",
        json={"status": "public"},
        headers=_auth(token),
    )
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED

    await _cleanup(db_session, user_id)


async def test_admin_letters_owner_filter(db_client, db_session) -> None:  # type: ignore[no-untyped-def]
    """owner=user 只看有主信，owner=seed 只看无主信。"""
    token, user_id = await _make_user(db_client)
    resp = await db_client.post("/v1/letters", json=_LETTER_BODY, headers=_auth(token))
    letter_id = resp.json()["id"]

    await _make_account(db_session, _ADMIN_USERNAME, "admin")
    admin_token = await _login(db_client, _ADMIN_USERNAME)

    resp = await db_client.get(
        "/v1/admin/letters", params={"owner": "user"}, headers=_auth(admin_token)
    )
    assert letter_id in [i["id"] for i in resp.json()["items"]]

    resp = await db_client.get(
        "/v1/admin/letters", params={"owner": "seed"}, headers=_auth(admin_token)
    )
    assert letter_id not in [i["id"] for i in resp.json()["items"]]

    await _cleanup(db_session, user_id)
