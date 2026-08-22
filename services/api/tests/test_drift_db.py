"""收信双入口：drift 抽取 / 开信标记 / discover（需真实数据库，@pytest.mark.db）。

收信 ≠ 已读语义的验收：
- 抽取写 served_at 去重（冷却内不重发），不动 read_count
- POST /letters/{id}/read 首开计数一次，重复开不重复计
- 已开封信永不再现；丢弃的未开封信冷却后回池
- discover 不返回 viewer 已开封信

共享云库纪律：坐标每轮随机（避免与其他轮次/他人的遗留数据撞点），
用户与信件经 actors fixture 在 teardown 统一清理（断言失败也清）。
"""

import random
import uuid
from collections.abc import AsyncGenerator
from typing import Any

import pytest
from sqlalchemy import delete, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.letter import Letter
from app.models.user import User

pytestmark = pytest.mark.db


def _rand_point() -> dict[str, float]:
    """随机落点（避开极地与反经线），确保 ST_DWithin 断言不受遗留数据干扰。"""
    return {"lat": round(random.uniform(-60, 60), 6), "lon": round(random.uniform(-170, 170), 6)}


async def _make_user(db_client: Any) -> tuple[str, str]:
    device_id = f"test-{uuid.uuid4().hex[:20]}"
    resp = await db_client.post("/v1/auth/device", json={"device_id": device_id})
    assert resp.status_code == 200
    return resp.json()["access_token"], resp.json()["user_id"]


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
async def actors(db_client: Any, db_session: AsyncSession) -> AsyncGenerator[dict[str, str]]:
    """writer（写信人）+ reader（收信人），teardown 统一清理其用户与信件。

    清理走 db_session（每测试独立引擎）——模块级 SessionLocal 跨事件循环会炸。
    """
    writer_token, writer = await _make_user(db_client)
    reader_token, reader = await _make_user(db_client)
    yield {
        "writer_token": writer_token,
        "writer": writer,
        "reader_token": reader_token,
        "reader": reader,
    }
    uids = [uuid.UUID(writer), uuid.UUID(reader)]
    await db_session.execute(delete(Letter).where(Letter.owner_user_id.in_(uids)))
    await db_session.execute(delete(User).where(User.id.in_(uids)))
    await db_session.commit()


async def _create_letter(db_client: Any, token: str, **extra: object) -> str:
    body: dict[str, object] = {
        "blocks": [{"type": "text", "text": f"海风把这句问候带给你 {uuid.uuid4().hex[:6]}"}],
        "delivery_mode": "drift",
    }
    body.update(extra)
    resp = await db_client.post("/v1/letters", json=body, headers=_auth(token))
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


async def _backdate_served(db_session: AsyncSession, letter_id: str, user_id: str) -> None:
    """把送达时间拨回 2 小时前，模拟冷却已过。"""
    await db_session.execute(
        text(
            "UPDATE letter_reads SET served_at = now() - interval '2 hours' "
            "WHERE letter_id = :lid AND user_id = :uid"
        ),
        {"lid": letter_id, "uid": user_id},
    )
    await db_session.commit()


async def test_drift_no_repeat_until_pool_empty(
    db_client: Any, actors: dict[str, str], moderation_on: None
) -> None:
    ids = {await _create_letter(db_client, actors["writer_token"]) for _ in range(3)}

    drawn = set()
    for _ in range(3):
        resp = await db_client.get("/v1/drift/next", headers=_auth(actors["reader_token"]))
        assert resp.status_code == 200
        drawn.add(resp.json()["id"])
    assert drawn == ids  # 连抽不重复且抽尽

    resp = await db_client.get("/v1/drift/next", headers=_auth(actors["reader_token"]))
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "drift_pool_empty"


async def test_drift_excludes_own_letters(
    db_client: Any, actors: dict[str, str], moderation_on: None
) -> None:
    await _create_letter(db_client, actors["writer_token"])
    resp = await db_client.get("/v1/drift/next", headers=_auth(actors["reader_token"]))
    assert resp.status_code == 200  # writer 的信可抽

    await _create_letter(db_client, actors["reader_token"])  # 自己的信不进自己的池
    resp = await db_client.get("/v1/drift/next", headers=_auth(actors["reader_token"]))
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "drift_pool_empty"


async def test_drift_read_once_count_and_never_redrawn(
    db_client: Any, db_session: AsyncSession, actors: dict[str, str], moderation_on: None
) -> None:
    letter_id = await _create_letter(db_client, actors["writer_token"])

    resp = await db_client.get("/v1/drift/next", headers=_auth(actors["reader_token"]))
    assert resp.status_code == 200
    # 抽取不计数
    assert resp.json()["counts"]["read"] == 0

    # 首开：204 + read_count 变 1
    resp = await db_client.post(
        f"/v1/letters/{letter_id}/read", headers=_auth(actors["reader_token"])
    )
    assert resp.status_code == 204
    got = await db_client.get(f"/v1/letters/{letter_id}")
    assert got.json()["counts"]["read"] == 1

    # 重复开信：不重复计
    await db_client.post(f"/v1/letters/{letter_id}/read", headers=_auth(actors["reader_token"]))
    got = await db_client.get(f"/v1/letters/{letter_id}")
    assert got.json()["counts"]["read"] == 1

    # 已开封 + 冷却已过 → 仍永不再现
    await _backdate_served(db_session, letter_id, actors["reader"])
    resp = await db_client.get("/v1/drift/next", headers=_auth(actors["reader_token"]))
    assert resp.status_code == 404


async def test_drift_discarded_unopened_redrawable_after_cooldown(
    db_client: Any, db_session: AsyncSession, actors: dict[str, str], moderation_on: None
) -> None:
    letter_id = await _create_letter(db_client, actors["writer_token"])

    resp = await db_client.get("/v1/drift/next", headers=_auth(actors["reader_token"]))
    assert resp.status_code == 200 and resp.json()["id"] == letter_id
    # 未开封，但冷却内 → 池空
    resp = await db_client.get("/v1/drift/next", headers=_auth(actors["reader_token"]))
    assert resp.status_code == 404

    # 冷却过后：同一封信重新漂来
    await _backdate_served(db_session, letter_id, actors["reader"])
    resp = await db_client.get("/v1/drift/next", headers=_auth(actors["reader_token"]))
    assert resp.status_code == 200 and resp.json()["id"] == letter_id


async def test_mark_read_direct_path_counts_once(
    db_client: Any, actors: dict[str, str], moderation_on: None
) -> None:
    """discover 直开（无 served 行）：insert 分支计数一次。"""
    letter_id = await _create_letter(db_client, actors["writer_token"])

    r1 = await db_client.post(
        f"/v1/letters/{letter_id}/read", headers=_auth(actors["reader_token"])
    )
    r2 = await db_client.post(
        f"/v1/letters/{letter_id}/read", headers=_auth(actors["reader_token"])
    )
    assert r1.status_code == r2.status_code == 204
    got = await db_client.get(f"/v1/letters/{letter_id}")
    assert got.json()["counts"]["read"] == 1


async def test_mark_read_pending_letter_404(db_client: Any, actors: dict[str, str]) -> None:
    letter_id = await _create_letter(db_client, actors["writer_token"])  # moderation 关 → pending
    resp = await db_client.post(
        f"/v1/letters/{letter_id}/read", headers=_auth(actors["writer_token"])
    )
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "letter_not_found"


async def test_discover_radius_order_and_opened_filter(
    db_client: Any, actors: dict[str, str], moderation_on: None
) -> None:
    center = _rand_point()

    # 先旧后新：created_at DESC 应返回 [新, 旧]
    near_old = await _create_letter(
        db_client,
        actors["writer_token"],
        delivery_mode="stay",
        **center,
        place_label="圈内·旧",
    )
    near_new = await _create_letter(
        db_client,
        actors["writer_token"],
        delivery_mode="stay",
        **center,
        place_label="圈内·新",
    )
    # 圈外（纬度 +0.5° ≈ 55km，远超默认 1000m 半径）
    await _create_letter(
        db_client,
        actors["writer_token"],
        delivery_mode="stay",
        lat=center["lat"] + 0.5,
        lon=center["lon"],
        place_label="圈外",
    )
    # drift 信不该出现在 discover
    await _create_letter(db_client, actors["writer_token"])

    resp = await db_client.get("/v1/discover", params=center, headers=_auth(actors["reader_token"]))
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert [i["id"] for i in items] == [near_new, near_old]  # created_at DESC，圈内、非 drift

    # 开掉一封 → 从列表消失
    await db_client.post(f"/v1/letters/{near_new}/read", headers=_auth(actors["reader_token"]))
    resp = await db_client.get("/v1/discover", params=center, headers=_auth(actors["reader_token"]))
    assert [i["id"] for i in resp.json()["items"]] == [near_old]
