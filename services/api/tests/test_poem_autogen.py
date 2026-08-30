"""寄出后自动写诗（后台任务）测试（@pytest.mark.db）。

覆盖：public 空诗信自动补写、客户端已带 poem 不覆盖、
pending 不触发、LLM 失败不影响寄出。
BackgroundTasks 在 ASGITransport 下随请求同步执行完才返回，
因此 POST /v1/letters 返回后即可断言 DB 中 poem 已回写。

**【停用】** 挂载点已注释（短诗现为客户端采纳制），整文件 skip 保留，
恢复 letters.py 挂载点后移除 skip 标记。现行语义由
test_letters_db.py::test_poem_absent_stays_null_even_with_ai_on 守住。
"""

import uuid
from collections.abc import AsyncGenerator

import pytest
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

import app.core.db as core_db
from app.core.config import get_settings
from app.models.letter import Letter
from app.models.user import User

pytestmark = [
    pytest.mark.db,
    pytest.mark.skip(reason="后台自动写诗链路停用中（挂载点已注释），启用后移除本标记"),
]

_POEM = "晚风掠过海面\n灯塔独自亮着\n想你"


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
    }
    body.update(extra)
    return body


async def _cleanup(session, user_id: str) -> None:  # type: ignore[no-untyped-def]
    await session.execute(delete(Letter).where(Letter.owner_user_id == uuid.UUID(user_id)))
    await session.execute(delete(User).where(User.id == uuid.UUID(user_id)))
    await session.commit()


@pytest.fixture
def ai_on(monkeypatch: pytest.MonkeyPatch, test_db_schema: str) -> None:
    """打开 feature_ai 并给齐 LLM 配置（conftest autouse 默认关闭）。

    必须依赖 test_db_schema：该 fixture 会 get_settings.cache_clear() 换新
    Settings 实例，先打补丁再换实例会被静默丢弃。
    """
    monkeypatch.setattr(get_settings(), "feature_ai", True)
    monkeypatch.setattr(get_settings(), "openai_api_key", "test-key")
    monkeypatch.setattr(get_settings(), "openai_base_url", "https://llm.example.com/v1")
    monkeypatch.setattr(get_settings(), "openai_model", "test-model")


@pytest.fixture
def mock_poem_llm(monkeypatch: pytest.MonkeyPatch):
    """chat_completion 替身：返回固定俳句；记录调用次数。"""
    calls = {"n": 0}

    async def _fake(messages, max_tokens):  # type: ignore[no-untyped-def]
        calls["n"] += 1
        return _POEM

    # 注意：ai_service 是顶层 from-import，必须 patch 它自己的命名空间
    monkeypatch.setattr("app.services.ai_service.chat_completion", _fake)
    return calls


@pytest.fixture
async def poem_session_factory(
    test_db_schema: str, monkeypatch: pytest.MonkeyPatch
) -> AsyncGenerator[None]:
    """让后台任务（自建 SessionLocal）也落在 test schema 上。"""
    from sqlalchemy.ext.asyncio import AsyncSession

    settings = get_settings()
    engine = create_async_engine(
        settings.database_url,
        connect_args={"server_settings": {"search_path": f"{test_db_schema},public"}},
    )
    factory = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)
    monkeypatch.setattr(core_db, "SessionLocal", factory)
    yield
    # 引擎在事件循环内释放，避免残留连接
    await engine.dispose()


async def test_public_letter_gets_auto_poem(
    db_client, db_session, moderation_on, ai_on, mock_poem_llm, poem_session_factory
):  # type: ignore[no-untyped-def]
    token, user_id = await _make_user(db_client)
    resp = await db_client.post("/v1/letters", json=_letter_body(), headers=_auth(token))
    assert resp.status_code == 201
    letter_id = resp.json()["id"]

    # 后台任务随请求执行完毕：poem 已回写且只调了一次 LLM
    assert mock_poem_llm["n"] == 1
    poem = await db_session.scalar(select(Letter.poem).where(Letter.id == letter_id))
    assert poem == _POEM
    await _cleanup(db_session, user_id)


async def test_client_provided_poem_not_overwritten(
    db_client, db_session, moderation_on, ai_on, mock_poem_llm, poem_session_factory
):  # type: ignore[no-untyped-def]
    token, user_id = await _make_user(db_client)
    own = "用户自己题的诗"
    resp = await db_client.post("/v1/letters", json=_letter_body(poem=own), headers=_auth(token))
    assert resp.status_code == 201
    letter_id = resp.json()["id"]
    assert resp.json()["poem"] == own

    # 客户端带诗时不调度后台任务，LLM 零调用
    assert mock_poem_llm["n"] == 0
    poem = await db_session.scalar(select(Letter.poem).where(Letter.id == letter_id))
    assert poem == own
    await _cleanup(db_session, user_id)


async def test_pending_letter_no_poem(
    db_client, db_session, ai_on, mock_poem_llm, poem_session_factory
):  # type: ignore[no-untyped-def]
    """moderation 关闭 → 信件 pending，不触发自动写诗。"""
    token, user_id = await _make_user(db_client)
    resp = await db_client.post("/v1/letters", json=_letter_body(), headers=_auth(token))
    assert resp.status_code == 201
    assert resp.json()["status"] == "pending"
    assert mock_poem_llm["n"] == 0
    poem = await db_session.scalar(select(Letter.poem).where(Letter.id == resp.json()["id"]))
    assert poem is None
    await _cleanup(db_session, user_id)


async def test_feature_ai_off_no_task(
    db_client, db_session, moderation_on, mock_poem_llm, poem_session_factory
):  # type: ignore[no-untyped-def]
    """FEATURE_AI=false（默认离线形态）：寄出正常，无诗无调用。"""
    token, user_id = await _make_user(db_client)
    resp = await db_client.post("/v1/letters", json=_letter_body(), headers=_auth(token))
    assert resp.status_code == 201
    assert resp.json()["status"] == "public"
    assert mock_poem_llm["n"] == 0
    await _cleanup(db_session, user_id)


async def test_llm_failure_does_not_break_create(
    db_client, db_session, moderation_on, ai_on, monkeypatch, poem_session_factory
):  # type: ignore[no-untyped-def]
    """LLM 抛错被后台任务吞掉：寄出仍 201，poem 保持 NULL。"""

    async def _boom(messages, max_tokens):  # type: ignore[no-untyped-def]
        raise OSError("llm down")

    monkeypatch.setattr("app.services.ai_service.chat_completion", _boom)
    token, user_id = await _make_user(db_client)
    resp = await db_client.post("/v1/letters", json=_letter_body(), headers=_auth(token))
    assert resp.status_code == 201
    poem = await db_session.scalar(select(Letter.poem).where(Letter.id == resp.json()["id"]))
    assert poem is None
    await _cleanup(db_session, user_id)
