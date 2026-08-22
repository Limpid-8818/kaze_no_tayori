"""互动与回信（需真实数据库，@pytest.mark.db）。

B4 验收：
- 共鸣幂等（重复调用两计数均不变），只回计数不回共鸣者
- 回信是独立信件（parent 溯源），原信 reply_count+1，作者收通知
- 纯过客信（无 owner）回信不通知不报错
- 举报入库（匿名可举报，非 public 404）
- 通知拉取 + 已读标记（只能标自己的）
"""

import uuid
from collections.abc import AsyncGenerator
from typing import Any

import pytest
from sqlalchemy import delete
from sqlalchemy import text as sql_text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.report import Report
from app.models.user import User

pytestmark = pytest.mark.db


async def _make_user(db_client: Any) -> tuple[str, str]:
    device_id = f"test-{uuid.uuid4().hex[:20]}"
    resp = await db_client.post("/v1/auth/device", json={"device_id": device_id})
    assert resp.status_code == 200
    return resp.json()["access_token"], resp.json()["user_id"]


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
async def actors(db_client: Any, db_session: AsyncSession) -> AsyncGenerator[dict[str, str]]:
    """author（原信作者）+ reader（互动者），teardown 清用户及其数据。

    清理走 db_session（每测试独立引擎）——模块级 SessionLocal 跨事件循环会炸。
    """
    author_token, author = await _make_user(db_client)
    reader_token, reader = await _make_user(db_client)
    yield {
        "author_token": author_token,
        "author": author,
        "reader_token": reader_token,
        "reader": reader,
    }
    uids = [uuid.UUID(author), uuid.UUID(reader)]
    # 通知/举报随用户与信件级联；信件按 owner 清
    await db_session.execute(
        sql_text("DELETE FROM letters WHERE owner_user_id = ANY(:uids)"),
        {"uids": [str(u) for u in uids]},
    )
    await db_session.execute(delete(User).where(User.id.in_(uids)))
    await db_session.commit()


async def _create_letter(db_client: Any, token: str, **extra: object) -> str:
    body: dict[str, object] = {
        "blocks": [{"type": "text", "text": f"落笔于此 {uuid.uuid4().hex[:6]}"}],
        "delivery_mode": "drift",
    }
    body.update(extra)
    resp = await db_client.post("/v1/letters", json=body, headers=_auth(token))
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


# ---------- 共鸣 ----------


async def test_resonate_idempotent_with_note(
    db_client: Any, actors: dict[str, str], moderation_on: None
) -> None:
    letter_id = await _create_letter(db_client, actors["author_token"])

    r1 = await db_client.post(
        f"/v1/letters/{letter_id}/resonance",
        json={"note": "我也曾有过这样的时刻"},
        headers=_auth(actors["reader_token"]),
    )
    assert r1.status_code == 200
    assert r1.json() == {"resonance_count": 1}  # 只回计数，无共鸣者位

    # 重复共鸣（再带 note）：计数均不变
    r2 = await db_client.post(
        f"/v1/letters/{letter_id}/resonance",
        json={"note": "再留一句"},
        headers=_auth(actors["reader_token"]),
    )
    assert r2.status_code == 200
    assert r2.json() == {"resonance_count": 1}

    got = await db_client.get(f"/v1/letters/{letter_id}")
    counts = got.json()["counts"]
    assert counts["resonance"] == 1
    assert counts["voice"] == 1  # 首次 note 才计一次


async def test_resonate_without_note_no_voice(
    db_client: Any, actors: dict[str, str], moderation_on: None
) -> None:
    letter_id = await _create_letter(db_client, actors["author_token"])
    r = await db_client.post(
        f"/v1/letters/{letter_id}/resonance", json={}, headers=_auth(actors["reader_token"])
    )
    assert r.json() == {"resonance_count": 1}
    got = await db_client.get(f"/v1/letters/{letter_id}")
    assert got.json()["counts"]["voice"] == 0


async def test_resonate_pending_letter_404(db_client: Any, actors: dict[str, str]) -> None:
    letter_id = await _create_letter(db_client, actors["author_token"])  # moderation 关 → pending
    r = await db_client.post(
        f"/v1/letters/{letter_id}/resonance",
        json={},
        headers=_auth(actors["reader_token"]),
    )
    assert r.status_code == 404


# ---------- 回信与通知 ----------


async def test_reply_creates_letter_and_notifies_author(
    db_client: Any, db_session: AsyncSession, actors: dict[str, str], moderation_on: None
) -> None:
    parent_id = await _create_letter(db_client, actors["author_token"], place_label="镰仓·海边")

    resp = await db_client.post(
        f"/v1/letters/{parent_id}/replies",
        json={"blocks": [{"type": "text", "text": "你的信漂到了我这里"}], "delivery_mode": "drift"},
        headers=_auth(actors["reader_token"]),
    )
    assert resp.status_code == 201
    reply = resp.json()
    assert reply["parent_letter_id"] == parent_id  # 独立信件 + 溯源
    assert reply["status"] == "public"

    # 原信 reply_count+1；公开回信列表可见且无作者位
    got = await db_client.get(f"/v1/letters/{parent_id}")
    assert got.json()["counts"]["reply"] == 1
    replies = await db_client.get(f"/v1/letters/{parent_id}/replies")
    assert replies.status_code == 200
    items = replies.json()["items"]
    assert [i["id"] for i in items] == [reply["id"]]
    assert "owner_user_id" not in items[0]

    # 原信作者收到通知（含原信地名），unread_only 可查
    notifications = await db_client.get(
        "/v1/me/notifications?unread_only=true", headers=_auth(actors["author_token"])
    )
    assert notifications.status_code == 200
    notes = notifications.json()["items"]
    assert len(notes) == 1
    assert notes[0]["type"] == "reply"
    assert notes[0]["letter_id"] == reply["id"]
    assert notes[0]["parent_letter_id"] == parent_id
    assert notes[0]["parent_place_label"] == "镰仓·海边"
    assert notes[0]["is_read"] is False

    # 标记已读：unread 消失，重复标记仍 204
    nid = notes[0]["id"]
    assert (
        await db_client.post(
            f"/v1/me/notifications/{nid}/read", headers=_auth(actors["author_token"])
        )
    ).status_code == 204
    assert (
        await db_client.post(
            f"/v1/me/notifications/{nid}/read", headers=_auth(actors["author_token"])
        )
    ).status_code == 204
    after = await db_client.get(
        "/v1/me/notifications?unread_only=true", headers=_auth(actors["author_token"])
    )
    assert after.json()["items"] == []


async def test_reply_to_ownerless_letter_no_notification(
    db_client: Any, db_session: AsyncSession, actors: dict[str, str], moderation_on: None
) -> None:
    """纯过客信（owner NULL）收到回信：静默跳过通知，回信照样公开。"""
    # 直插一封无主 public 信（模拟种子信）
    parent_id = str(uuid.uuid4())
    await db_session.execute(
        sql_text(
            "INSERT INTO letters (id, blocks, theme_id, tags, delivery_mode, status, place_label) "
            'VALUES (CAST(:id AS uuid), \'[{"type":"text","text":"无主信"}]\'::jsonb, '
            "'natsu', '[]'::jsonb, 'drift', 'public', '无人之境')"
        ),
        {"id": parent_id},
    )
    await db_session.commit()

    resp = await db_client.post(
        f"/v1/letters/{parent_id}/replies",
        json={"blocks": [{"type": "text", "text": "路过的回信"}], "delivery_mode": "drift"},
        headers=_auth(actors["reader_token"]),
    )
    assert resp.status_code == 201

    # reader（回信人）与 author 都不该有新通知
    for token in (actors["author_token"], actors["reader_token"]):
        notes = await db_client.get("/v1/me/notifications", headers=_auth(token))
        assert notes.json()["items"] == []

    # 清理这封直插信（无 owner，不随 actors teardown 级联）
    await db_session.execute(
        sql_text("DELETE FROM letters WHERE id = CAST(:id AS uuid)"), {"id": parent_id}
    )
    await db_session.commit()


async def test_cannot_mark_others_notification(
    db_client: Any, db_session: AsyncSession, actors: dict[str, str], moderation_on: None
) -> None:
    parent_id = await _create_letter(db_client, actors["author_token"])
    await db_client.post(
        f"/v1/letters/{parent_id}/replies",
        json={"blocks": [{"type": "text", "text": "hi"}], "delivery_mode": "drift"},
        headers=_auth(actors["reader_token"]),
    )
    notes = (
        await db_client.get("/v1/me/notifications", headers=_auth(actors["author_token"]))
    ).json()["items"]
    assert len(notes) == 1
    # reader 想标 author 的通知 → 404（不泄漏存在性）
    r = await db_client.post(
        f"/v1/me/notifications/{notes[0]['id']}/read", headers=_auth(actors["reader_token"])
    )
    assert r.status_code == 404


# ---------- 举报 ----------


async def test_report_logged_and_anonymous_ok(
    db_client: Any, db_session: AsyncSession, actors: dict[str, str], moderation_on: None
) -> None:
    letter_id = await _create_letter(db_client, actors["author_token"])

    # 登录举报
    r1 = await db_client.post(
        f"/v1/letters/{letter_id}/report",
        json={"reason": "spam", "detail": "疑似广告"},
        headers=_auth(actors["reader_token"]),
    )
    assert r1.status_code == 204
    # 匿名举报
    r2 = await db_client.post(f"/v1/letters/{letter_id}/report", json={"reason": "other"})
    assert r2.status_code == 204

    from sqlalchemy import select

    reports = (
        (await db_session.execute(select(Report).where(Report.letter_id == uuid.UUID(letter_id))))
        .scalars()
        .all()
    )
    assert len(reports) == 2
    assert {r.reporter_user_id is not None for r in reports} == {True, False}


async def test_report_pending_letter_404(db_client: Any, actors: dict[str, str]) -> None:
    letter_id = await _create_letter(db_client, actors["author_token"])  # pending
    r = await db_client.post(f"/v1/letters/{letter_id}/report", json={"reason": "spam"})
    assert r.status_code == 404


# ---------- B5 · me 全家桶 ----------


async def test_my_letters_contains_pending_and_excludes_others(
    db_client: Any, db_session: AsyncSession, actors: dict[str, str]
) -> None:
    """我的信列表：含 pending、按 created_at DESC，且不含他人信。"""
    # author 建两封（moderation 关 → pending）
    id1 = await _create_letter(db_client, actors["author_token"], place_label="A")
    id2 = await _create_letter(db_client, actors["author_token"], place_label="B")

    # reader 建一封
    id_other = await _create_letter(db_client, actors["reader_token"], place_label="C")

    page = (
        await db_client.get("/v1/me/letters?limit=20", headers=_auth(actors["author_token"]))
    ).json()
    assert page["next_cursor"] is None
    ids = [item["id"] for item in page["items"]]
    assert id1 in ids and id2 in ids
    assert id_other not in ids
    # status 含 pending
    statuses = {item["status"] for item in page["items"]}
    assert "pending" in statuses
    # LetterOwned 含 lat/lon（stay 信有坐标，drift 信为 null）
    for item in page["items"]:
        assert "lat" in item and "lon" in item


async def test_take_down_soft_deletes_and_preserves_chain(
    db_client: Any, db_session: AsyncSession, actors: dict[str, str], moderation_on: None
) -> None:
    """下架后读者侧 404，parent_letter_id 仍存在（回信链不塌）。"""
    parent_id = await _create_letter(db_client, actors["author_token"], place_label="原点")

    # 回信
    reply_resp = await db_client.post(
        f"/v1/letters/{parent_id}/replies",
        json={"blocks": [{"type": "text", "text": "回信"}], "delivery_mode": "drift"},
        headers=_auth(actors["reader_token"]),
    )
    assert reply_resp.status_code == 201
    reply_id = reply_resp.json()["id"]

    # 下架原信
    r = await db_client.delete(f"/v1/me/letters/{parent_id}", headers=_auth(actors["author_token"]))
    assert r.status_code == 204

    # 读者侧原信 404
    got = await db_client.get(f"/v1/letters/{parent_id}")
    assert got.status_code == 404

    # 回信仍在，parent_letter_id 未断
    reply_row = await db_session.execute(
        sql_text("SELECT parent_letter_id FROM letters WHERE id = CAST(:id AS uuid)"),
        {"id": reply_id},
    )
    assert reply_row.scalar_one() == uuid.UUID(parent_id)


async def test_non_owner_take_down_returns_404(
    db_client: Any, actors: dict[str, str], moderation_on: None
) -> None:
    """非 owner 下架他人信 → 404（不区分「不存在」与「不是你的」）。"""
    letter_id = await _create_letter(db_client, actors["author_token"])
    r = await db_client.delete(f"/v1/me/letters/{letter_id}", headers=_auth(actors["reader_token"]))
    assert r.status_code == 404


async def test_scripbook_add_idempotent(
    db_client: Any, db_session: AsyncSession, actors: dict[str, str], moderation_on: None
) -> None:
    """抄本添加幂等：两次添加 saved_count 只 +1。"""
    letter_id = await _create_letter(db_client, actors["author_token"])

    # 第一次添加
    r1 = await db_client.post(
        "/v1/me/scripbook",
        json={"letter_id": letter_id},
        headers=_auth(actors["reader_token"]),
    )
    assert r1.status_code == 204

    counts_after_first = (
        await db_session.execute(
            sql_text("SELECT saved_count FROM letters WHERE id = CAST(:id AS uuid)"),
            {"id": letter_id},
        )
    ).scalar_one()
    assert counts_after_first == 1

    # 第二次添加（幂等）
    r2 = await db_client.post(
        "/v1/me/scripbook",
        json={"letter_id": letter_id},
        headers=_auth(actors["reader_token"]),
    )
    assert r2.status_code == 204

    counts_after_second = (
        await db_session.execute(
            sql_text("SELECT saved_count FROM letters WHERE id = CAST(:id AS uuid)"),
            {"id": letter_id},
        )
    ).scalar_one()
    assert counts_after_second == 1  # 不再增加


async def test_scripbook_remove_decrements_and_floors_at_zero(
    db_client: Any, db_session: AsyncSession, actors: dict[str, str], moderation_on: None
) -> None:
    """移除抄本条目：saved_count 递减，且 floor 0。"""
    letter_id = await _create_letter(db_client, actors["author_token"])
    await db_client.post(
        "/v1/me/scripbook",
        json={"letter_id": letter_id},
        headers=_auth(actors["reader_token"]),
    )

    # 移除
    r = await db_client.delete(
        f"/v1/me/scripbook/{letter_id}", headers=_auth(actors["reader_token"])
    )
    assert r.status_code == 204

    saved = (
        await db_session.execute(
            sql_text("SELECT saved_count FROM letters WHERE id = CAST(:id AS uuid)"),
            {"id": letter_id},
        )
    ).scalar_one()
    assert saved == 0

    # 再次移除：已不在抄本中 → 404（与 mark_read 一致：资源不存在即 404）
    r2 = await db_client.delete(
        f"/v1/me/scripbook/{letter_id}", headers=_auth(actors["reader_token"])
    )
    assert r2.status_code == 404
    # saved_count 仍为 0（floor 不松动）
    saved_again = (
        await db_session.execute(
            sql_text("SELECT saved_count FROM letters WHERE id = CAST(:id AS uuid)"),
            {"id": letter_id},
        )
    ).scalar_one()
    assert saved_again == 0


async def test_scripbook_remove_not_in_scripbook_returns_404(
    db_client: Any, actors: dict[str, str], moderation_on: None
) -> None:
    """从抄本移除不存在的条目 → 404。"""
    letter_id = await _create_letter(db_client, actors["author_token"])
    r = await db_client.delete(
        f"/v1/me/scripbook/{letter_id}", headers=_auth(actors["reader_token"])
    )
    assert r.status_code == 404
