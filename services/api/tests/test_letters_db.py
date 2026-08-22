"""写信链路（需真实数据库，@pytest.mark.db）。

共享云库纪律：自造自清，结束只删自己插的 user 与其信件。
"""

import uuid

import pytest
from geoalchemy2 import WKTElement
from sqlalchemy import delete, func, select

from app.core.config import get_settings
from app.models.letter import Letter
from app.models.user import User
from app.services import moderation_service

pytestmark = pytest.mark.db


async def _make_user(db_client) -> tuple[str, str]:  # type: ignore[no-untyped-def]
    device_id = f"test-{uuid.uuid4().hex[:20]}"
    resp = await db_client.post("/v1/auth/device", json={"device_id": device_id})
    assert resp.status_code == 200
    return resp.json()["access_token"], resp.json()["user_id"]


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _letter_body(**extra: object) -> dict[str, object]:  # type: ignore[type-arg]
    body: dict[str, object] = {
        "blocks": [{"type": "text", "text": "海风把这句问候带给你"}],
        "delivery_mode": "drift",
        "tags": ["travel", "sea"],
    }
    body.update(extra)
    return body


async def _cleanup(session, user_id: str) -> None:  # type: ignore[no-untyped-def]
    await session.execute(delete(Letter).where(Letter.owner_user_id == uuid.UUID(user_id)))
    await session.execute(delete(User).where(User.id == uuid.UUID(user_id)))
    await session.commit()


@pytest.fixture
def moderation_on(monkeypatch: pytest.MonkeyPatch) -> None:
    settings = get_settings()
    monkeypatch.setattr(settings, "feature_moderation", True)


async def test_create_drift_letter_defaults_pending(db_client, db_session):  # type: ignore[no-untyped-def]
    """FEATURE_MODERATION=false（默认）→ pending（红线 8：关闭即待审不公开）。"""
    token, user_id = await _make_user(db_client)
    resp = await db_client.post("/v1/letters", json=_letter_body(), headers=_auth(token))
    assert resp.status_code == 201
    body = resp.json()
    assert body["status"] == "pending"
    assert body["delivery_mode"] == "drift"
    assert body["tags"] == ["travel", "sea"]
    assert body["counts"]["read"] == 0
    # 匿名守卫：响应体不含任何作者标识 / 精确坐标 / status 之外的泄漏位
    assert "owner_user_id" not in body
    assert body["lat"] is None and body["lon"] is None
    await _cleanup(db_session, user_id)


async def test_create_drift_public_when_moderation_on(  # type: ignore[no-untyped-def]
    db_client, db_session, moderation_on
):
    """FEATURE_MODERATION=true + 空关键词表 → public（契约允许的开发路径）。"""
    token, user_id = await _make_user(db_client)
    resp = await db_client.post("/v1/letters", json=_letter_body(), headers=_auth(token))
    assert resp.status_code == 201
    assert resp.json()["status"] == "public"
    await _cleanup(db_session, user_id)


async def test_create_rejected_on_blocklist(  # type: ignore[no-untyped-def]
    db_client, db_session, moderation_on, monkeypatch
):
    monkeypatch.setattr(moderation_service, "BLOCKLIST", ("违禁词",))
    token, user_id = await _make_user(db_client)
    resp = await db_client.post(
        "/v1/letters",
        json=_letter_body(blocks=[{"type": "text", "text": "这里有一个违禁词"}]),
        headers=_auth(token),
    )
    assert resp.status_code == 201
    assert resp.json()["status"] == "rejected"
    # rejected 不泄漏存在性：公开读一律 404
    got = await db_client.get(f"/v1/letters/{resp.json()['id']}")
    assert got.status_code == 404
    assert got.json()["error"]["code"] == "letter_not_found"
    await _cleanup(db_session, user_id)


async def test_stay_requires_location(db_client, db_session, moderation_on):  # type: ignore[no-untyped-def]
    token, user_id = await _make_user(db_client)
    resp = await db_client.post(
        "/v1/letters", json=_letter_body(delivery_mode="stay"), headers=_auth(token)
    )
    assert resp.status_code == 400
    assert resp.json()["error"]["code"] == "stay_requires_location"
    await _cleanup(db_session, user_id)


async def test_stay_letter_located_and_readable(  # type: ignore[no-untyped-def]
    db_client, db_session, moderation_on
):
    token, user_id = await _make_user(db_client)
    lon, lat = 139.7671, 35.6812  # 东京站附近
    resp = await db_client.post(
        "/v1/letters",
        json=_letter_body(delivery_mode="stay", lat=lat, lon=lon, place_label="东京·车站"),
        headers=_auth(token),
    )
    assert resp.status_code == 201
    letter_id = resp.json()["id"]
    assert resp.json()["status"] == "public"

    # 落库的是 geography POINT，且能被 ST_DWithin 就地查到（B3 的地基）
    point = WKTElement(f"POINT({lon} {lat})", srid=4326, extended=True)
    found = await db_session.scalar(
        select(func.count()).select_from(Letter).where(func.ST_DWithin(Letter.location, point, 0))
    )
    assert found == 1

    # 公开读 200，且不泄漏坐标
    got = await db_client.get(f"/v1/letters/{letter_id}")
    assert got.status_code == 200
    assert got.json()["place_label"] == "东京·车站"
    assert "lat" not in got.json() and "lon" not in got.json()
    await _cleanup(db_session, user_id)
