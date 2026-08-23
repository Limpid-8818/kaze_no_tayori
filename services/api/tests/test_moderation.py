"""LLM 审核模块测试。

覆盖：feature 禁用、关键词命中、LLM APPROVED/REJECTED、LLM 失败/乱码 → PENDING（红线 8）。
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.core.config import get_settings
from app.models.enums import LetterStatus
from app.services import moderation_service
from app.services.moderation_service import moderate

_BLOCKS = [{"type": "text", "text": "今晚的风很轻，我在海边想你。"}]


def _enable_moderation(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "feature_moderation", True)
    monkeypatch.setattr(get_settings(), "openai_api_key", "test-key")
    monkeypatch.setattr(get_settings(), "openai_base_url", "https://llm.example.com/v1")
    monkeypatch.setattr(get_settings(), "openai_model", "test-model")


def _make_mock_client(json_data: dict, status_code: int = 200) -> AsyncMock:
    resp = MagicMock()
    resp.status_code = status_code
    resp.json.return_value = json_data
    client = AsyncMock()
    client.__aenter__ = AsyncMock(return_value=client)
    client.__aexit__ = AsyncMock(return_value=False)
    client.post.return_value = resp
    return client


def _llm_response(content: str) -> dict:
    return {"choices": [{"message": {"content": content}}]}


@pytest.mark.asyncio
async def test_moderation_feature_disabled(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "feature_moderation", False)
    assert await moderate(_BLOCKS) is LetterStatus.PENDING


@pytest.mark.asyncio
async def test_moderation_llm_approved(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_moderation(monkeypatch)
    client = _make_mock_client(_llm_response("APPROVED"))
    with patch("app.services.llm_client.httpx.AsyncClient", return_value=client):
        assert await moderate(_BLOCKS) is LetterStatus.PUBLIC


@pytest.mark.asyncio
async def test_moderation_llm_rejected(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_moderation(monkeypatch)
    client = _make_mock_client(_llm_response("REJECTED"))
    with patch("app.services.llm_client.httpx.AsyncClient", return_value=client):
        assert await moderate(_BLOCKS) is LetterStatus.REJECTED


@pytest.mark.asyncio
async def test_moderation_blocklist_hit(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_moderation(monkeypatch)
    monkeypatch.setattr(moderation_service, "BLOCKLIST", ("违禁词",))
    assert await moderate([{"type": "text", "text": "这里有违禁词"}]) is LetterStatus.REJECTED


@pytest.mark.asyncio
async def test_moderation_llm_failure_falls_back_pending(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_moderation(monkeypatch)
    with patch("app.services.llm_client.httpx.AsyncClient", side_effect=OSError("down")):
        assert await moderate(_BLOCKS) is LetterStatus.PENDING


@pytest.mark.asyncio
async def test_moderation_llm_unparseable_falls_back_pending(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _enable_moderation(monkeypatch)
    client = _make_mock_client(_llm_response("我觉得这封信还不错"))
    with patch("app.services.llm_client.httpx.AsyncClient", return_value=client):
        assert await moderate(_BLOCKS) is LetterStatus.PENDING


@pytest.mark.asyncio
async def test_moderation_llm_non_200_falls_back_pending(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _enable_moderation(monkeypatch)
    client = _make_mock_client({"error": "rate limited"}, status_code=429)
    with patch("app.services.llm_client.httpx.AsyncClient", return_value=client):
        assert await moderate(_BLOCKS) is LetterStatus.PENDING


@pytest.mark.asyncio
async def test_moderation_no_key_falls_back_pending(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_moderation(monkeypatch)
    monkeypatch.setattr(get_settings(), "openai_api_key", "")
    assert await moderate(_BLOCKS) is LetterStatus.PENDING
