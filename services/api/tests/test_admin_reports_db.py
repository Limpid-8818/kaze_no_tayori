"""管理端举报处置链路（需真实数据库，@pytest.mark.db）。

举报只能对 public 信发起（letter_service.create_report 的 public 守卫），
所以本文件用 moderation_on 让信直接公开。自造自清纪律同 test_feedback_db。
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

_ADMIN_USERNAME = "test-reports-admin"


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


async def _make_user(db_client: AsyncClient) -> tuple[str, str]:
    resp = await db_client.post(
        "/v1/auth/device", json={"device_id": f"test-{uuid.uuid4().hex[:20]}"}
    )
    assert resp.status_code == 200
    return resp.json()["access_token"], resp.json()["user_id"]


async def _cleanup(db_session, user_id: str) -> None:  # type: ignore[no-untyped-def]
    await db_session.execute(delete(Letter).where(Letter.owner_user_id == uuid.UUID(user_id)))
    await db_session.execute(delete(User).where(User.id == uuid.UUID(user_id)))
    await db_session.execute(delete(AdminAccount).where(AdminAccount.username == _ADMIN_USERNAME))
    await db_session.commit()


async def test_admin_report_flow(
    db_client,
    db_session,
    moderation_on,  # type: ignore[no-untyped-def]
) -> None:
    """public 信被举报 → 管理端 open 列表 → dismissed/actioned 流转 handled_at。"""
    token, user_id = await _make_user(db_client)
    resp = await db_client.post(
        "/v1/letters",
        json={
            "blocks": [{"type": "text", "text": "这封信被举报了"}],
            "delivery_mode": "drift",
        },
        headers=_auth(token),
    )
    assert resp.status_code == status.HTTP_201_CREATED
    letter_id = resp.json()["id"]
    assert resp.json()["status"] == "public"  # moderation_on → 直接过审

    # 读者举报（reporter 就是写信人，无妨）
    resp = await db_client.post(
        f"/v1/letters/{letter_id}/report",
        json={"reason": "不当内容", "detail": "测试举报"},
        headers=_auth(token),
    )
    assert resp.status_code == status.HTTP_204_NO_CONTENT

    # admin 登录看 open 列表：涉事信摘要内嵌
    db_session.add(
        AdminAccount(
            username=_ADMIN_USERNAME,
            password_hash=hash_password("test-password-123"),
            role="admin",
        )
    )
    await db_session.commit()
    resp = await db_client.post(
        "/v1/admin/login",
        json={"username": _ADMIN_USERNAME, "password": "test-password-123"},
    )
    admin_token = resp.json()["access_token"]

    resp = await db_client.get("/v1/admin/reports", headers=_auth(admin_token))
    assert resp.status_code == status.HTTP_200_OK
    items = resp.json()["items"]
    target = next(i for i in items if i["letter"]["id"] == letter_id)
    report_id = target["id"]
    assert target["status"] == "open"
    assert target["reason"] == "不当内容"
    assert "举报" in target["letter"]["preview"]
    assert target["handled_at"] is None

    # dismissed → handled_at 回写
    resp = await db_client.patch(
        f"/v1/admin/reports/{report_id}",
        json={"status": "dismissed", "admin_note": "核查无问题"},
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_200_OK
    body = resp.json()
    assert body["status"] == "dismissed"
    assert body["handled_at"] is not None
    assert body["admin_note"] == "核查无问题"

    # 回退 open → handled_at 清空
    resp = await db_client.patch(
        f"/v1/admin/reports/{report_id}",
        json={"status": "open"},
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_200_OK
    assert resp.json()["handled_at"] is None

    # 空体 → 422；不存在的举报 → 404
    resp = await db_client.patch(
        f"/v1/admin/reports/{report_id}", json={}, headers=_auth(admin_token)
    )
    assert resp.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
    resp = await db_client.patch(
        f"/v1/admin/reports/{uuid.uuid4()}",
        json={"status": "actioned"},
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_404_NOT_FOUND

    # 状态流转：open → actioned，open 筛选不再包含它
    resp = await db_client.patch(
        f"/v1/admin/reports/{report_id}",
        json={"status": "actioned"},
        headers=_auth(admin_token),
    )
    assert resp.status_code == status.HTTP_200_OK
    resp = await db_client.get(
        "/v1/admin/reports", params={"status": "open"}, headers=_auth(admin_token)
    )
    assert report_id not in [i["id"] for i in resp.json()["items"]]

    await _cleanup(db_session, user_id)
