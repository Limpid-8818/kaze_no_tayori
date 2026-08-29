"""写信链路（需真实数据库，@pytest.mark.db）。

共享云库纪律：自造自清，结束只删自己插的 user 与其信件。
"""

import random
import uuid

import pytest
from geoalchemy2 import WKTElement
from sqlalchemy import delete, func, select

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


async def test_create_drift_letter_defaults_pending(db_client, db_session):  # type: ignore[no-untyped-def]
    """FEATURE_MODERATION=false（默认）→ pending（红线 8：关闭即待审不公开）。"""
    token, user_id = await _make_user(db_client)
    resp = await db_client.post(
        "/v1/letters",
        json=_letter_body(signature="海边的风", addressee="远方的你"),
        headers=_auth(token),
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["status"] == "pending"
    assert body["delivery_mode"] == "drift"
    assert body["tags"] == ["travel", "sea"]
    # 署名与宛名是信件内容物：建信回显 + 公开读 round-trip 一致
    assert body["signature"] == "海边的风"
    assert body["addressee"] == "远方的你"
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
    # 随机落点，避免与共享库遗留数据撞点
    lat, lon = round(random.uniform(-60, 60), 6), round(random.uniform(-170, 170), 6)
    resp = await db_client.post(
        "/v1/letters",
        json=_letter_body(delivery_mode="stay", lat=lat, lon=lon, place_label="随机·落点"),
        headers=_auth(token),
    )
    assert resp.status_code == 201
    letter_id = resp.json()["id"]
    assert resp.json()["status"] == "public"

    # 落库的是 geography POINT，且能被 ST_DWithin 就地查到（B3 的地基）
    point = WKTElement(f"POINT({lon} {lat})", srid=4326, extended=True)
    found = await db_session.scalar(
        select(Letter.id).where(Letter.id == letter_id, func.ST_DWithin(Letter.location, point, 0))
    )
    assert str(found) == letter_id

    # 公开读 200，落点坐标按 2026-08 裁决对外下发（读者算直线距离用）
    got = await db_client.get(f"/v1/letters/{letter_id}")
    assert got.status_code == 200
    assert got.json()["place_label"] == "随机·落点"
    assert got.json()["lat"] == lat and got.json()["lon"] == lon
    await _cleanup(db_session, user_id)


async def test_signature_addressee_roundtrip(  # type: ignore[no-untyped-def]
    db_client, db_session, moderation_on
):
    """署名/宛名建信 → 公开读 round-trip（可空时往返都是 None）。"""
    token, user_id = await _make_user(db_client)
    resp = await db_client.post(
        "/v1/letters",
        json=_letter_body(signature="夏未", addressee="拾信的你"),
        headers=_auth(token),
    )
    assert resp.status_code == 201
    letter_id = resp.json()["id"]

    got = await db_client.get(f"/v1/letters/{letter_id}")
    assert got.status_code == 200
    assert got.json()["signature"] == "夏未"
    assert got.json()["addressee"] == "拾信的你"

    # 不携带两字段的老客户端：缺省 None，往返均为 None
    resp2 = await db_client.post("/v1/letters", json=_letter_body(), headers=_auth(token))
    assert resp2.status_code == 201
    got2 = await db_client.get(f"/v1/letters/{resp2.json()['id']}")
    assert got2.json()["signature"] is None
    assert got2.json()["addressee"] is None
    await _cleanup(db_session, user_id)
