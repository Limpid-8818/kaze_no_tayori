"""AI 短诗/润色模块测试。

覆盖：feature 禁用、无 key、正文为空、成功（俳句格式）、网络失败、非 200、空 content。
契约：一切失败 → FeatureDisabled，绝不 500。
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.core.config import get_settings
from app.core.errors import FeatureDisabled
from app.services.ai_service import compose_poem, polish

_BLOCKS = [{"type": "text", "text": "今晚的风很轻，我在海边想你。"}]


def _enable_ai(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "feature_ai", True)
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


# ---------- polish ----------


@pytest.mark.asyncio
async def test_polish_success(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_ai(monkeypatch)
    client = _make_mock_client(_llm_response("今晚的风很轻，我在海边想你。"))
    with patch("app.services.llm_client.httpx.AsyncClient", return_value=client):
        result = await polish(_BLOCKS)
    assert result == "今晚的风很轻，我在海边想你。"


@pytest.mark.asyncio
async def test_polish_feature_disabled(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "feature_ai", False)
    with pytest.raises(FeatureDisabled):
        await polish(_BLOCKS)


@pytest.mark.asyncio
async def test_polish_no_key(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_ai(monkeypatch)
    monkeypatch.setattr(get_settings(), "openai_api_key", "")
    with pytest.raises(FeatureDisabled):
        await polish(_BLOCKS)


@pytest.mark.asyncio
async def test_polish_empty_text(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_ai(monkeypatch)
    with pytest.raises(FeatureDisabled):
        await polish([{"type": "image", "url": "https://x/img.png"}])


@pytest.mark.asyncio
async def test_polish_network_error(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_ai(monkeypatch)
    with (
        patch("app.services.llm_client.httpx.AsyncClient", side_effect=OSError("down")),
        pytest.raises(FeatureDisabled),
    ):
        await polish(_BLOCKS)


@pytest.mark.asyncio
async def test_polish_non_200(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_ai(monkeypatch)
    client = _make_mock_client({"error": "quota"}, status_code=429)
    with (
        patch("app.services.llm_client.httpx.AsyncClient", return_value=client),
        pytest.raises(FeatureDisabled),
    ):
        await polish(_BLOCKS)


@pytest.mark.asyncio
async def test_polish_empty_content(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_ai(monkeypatch)
    client = _make_mock_client(_llm_response("  "))
    with (
        patch("app.services.llm_client.httpx.AsyncClient", return_value=client),
        pytest.raises(FeatureDisabled),
    ):
        await polish(_BLOCKS)


# ---------- compose_poem（默认俳句） ----------


@pytest.mark.asyncio
async def test_compose_poem_haiku_format(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_ai(monkeypatch)
    haiku = "晚风掠过海面\n灯塔独自亮着\n想你"
    client = _make_mock_client(_llm_response(haiku))
    with patch("app.services.llm_client.httpx.AsyncClient", return_value=client):
        result = await compose_poem(_BLOCKS)
    assert result == haiku
    assert len(result.splitlines()) == 3


@pytest.mark.asyncio
async def test_compose_poem_feature_disabled(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "feature_ai", False)
    with pytest.raises(FeatureDisabled):
        await compose_poem(_BLOCKS)


@pytest.mark.asyncio
async def test_compose_poem_timeout(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_ai(monkeypatch)
    import httpx

    with (
        patch(
            "app.services.llm_client.httpx.AsyncClient",
            side_effect=httpx.TimeoutException("timeout"),
        ),
        pytest.raises(FeatureDisabled),
    ):
        await compose_poem(_BLOCKS)
