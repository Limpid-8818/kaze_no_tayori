"""天气模块测试。

覆盖：正常返回、feature 禁用、无 key、geo 失败降级、QWeather 异常、缓存命中。
"""

from __future__ import annotations

import time
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.core.config import get_settings
from app.schemas.letter import Weather
from app.services.weather_service import (
    _CACHE,
    _cache_get,
    _cache_set,
    _fetch_from_qweather,
    _get_location_id,
    fetch_weather,
)

# ---------- 辅助 ----------


def _enable_weather(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "feature_weather", True)
    monkeypatch.setattr(get_settings(), "weather_api_key", "test-key")
    monkeypatch.setattr(get_settings(), "weather_api_host", "https://devapi.qweather.com")


def _make_qweather_response(text: str = "晴", temp: str = "25") -> dict:
    return {"code": "200", "now": {"temp": temp, "text": text}}


def _make_mock_client(json_data: dict) -> tuple[AsyncMock, MagicMock]:
    """构造 mock httpx.AsyncClient + response。

    resp.json() 是 httpx 的同步方法，用 MagicMock；client 是 async context manager，用 AsyncMock。
    """
    resp = MagicMock()
    resp.status_code = 200
    resp.json.return_value = json_data

    client = AsyncMock()
    client.__aenter__ = AsyncMock(return_value=client)
    client.__aexit__ = AsyncMock(return_value=False)
    client.get.return_value = resp
    return client, resp


# ---------- _get_location_id ----------


@pytest.mark.asyncio
async def test_get_location_id_success() -> None:
    client, _ = _make_mock_client(
        {
            "code": "200",
            "location": [{"id": "101011600", "name": "东城"}],
        }
    )
    with patch("app.services.weather_service.httpx.AsyncClient", return_value=client):
        result = await _get_location_id(39.92, 116.41)
    assert result == "101011600"


@pytest.mark.asyncio
async def test_get_location_id_feature_disabled(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "feature_weather", False)
    monkeypatch.setattr(get_settings(), "weather_api_key", "test-key")
    result = await _get_location_id(39.92, 116.41)
    assert result is None


@pytest.mark.asyncio
async def test_get_location_id_no_key(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "feature_weather", True)
    monkeypatch.setattr(get_settings(), "weather_api_key", "")
    result = await _get_location_id(39.92, 116.41)
    assert result is None


@pytest.mark.asyncio
async def test_get_location_id_network_error(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_weather(monkeypatch)
    with patch(
        "app.services.weather_service.httpx.AsyncClient", side_effect=OSError("network down")
    ):
        result = await _get_location_id(39.92, 116.41)
    assert result is None


@pytest.mark.asyncio
async def test_get_location_id_empty_location_list(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_weather(monkeypatch)
    client, _ = _make_mock_client({"code": "200", "location": []})
    with patch("app.services.weather_service.httpx.AsyncClient", return_value=client):
        result = await _get_location_id(39.92, 116.41)
    assert result is None


# ---------- _fetch_from_qweather ----------


@pytest.mark.asyncio
async def test_fetch_from_qweather_success() -> None:
    client, _ = _make_mock_client(_make_qweather_response("多云", "22"))
    with patch("app.services.weather_service.httpx.AsyncClient", return_value=client):
        result = await _fetch_from_qweather("101010100")
    assert result == Weather(text="多云", temp_c=22.0, icon="cloudy")


@pytest.mark.asyncio
async def test_fetch_from_qweather_network_error() -> None:
    with patch(
        "app.services.weather_service.httpx.AsyncClient", side_effect=OSError("network down")
    ):
        result = await _fetch_from_qweather("101010100")
    assert result is None


@pytest.mark.asyncio
async def test_fetch_from_qweather_non_200() -> None:
    client, _ = _make_mock_client(_make_qweather_response("晴", "25"))
    client.get.return_value.status_code = 500
    with patch("app.services.weather_service.httpx.AsyncClient", return_value=client):
        result = await _fetch_from_qweather("101010100")
    assert result is None


@pytest.mark.asyncio
async def test_fetch_from_qweather_api_error_code() -> None:
    client, _ = _make_mock_client({"code": "204", "now": {}})
    with patch("app.services.weather_service.httpx.AsyncClient", return_value=client):
        result = await _fetch_from_qweather("101010100")
    assert result is None


@pytest.mark.asyncio
async def test_fetch_from_qweather_missing_text() -> None:
    client, _ = _make_mock_client({"code": "200", "now": {"temp": "25", "text": ""}})
    with patch("app.services.weather_service.httpx.AsyncClient", return_value=client):
        result = await _fetch_from_qweather("101010100")
    assert result is None


# ---------- icon 映射 ----------


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("晴", "sunny"),
        ("晴朗", "sunny"),
        ("多云", "cloudy"),
        ("阴", "cloudy"),
        ("小雨", "rainy"),
        ("中雨", "rainy"),
        ("雷阵雨", "rainy"),
        ("小雪", "rainy"),
        ("大雾", "rainy"),
        ("霾", "rainy"),
        ("未知天气", "cloudy"),
    ],
)
def test_map_icon(text: str, expected: str) -> None:
    from app.services.weather_service import _map_icon

    assert _map_icon(text) == expected


# ---------- 缓存 ----------


def test_cache_set_and_get() -> None:
    _CACHE.clear()
    weather = Weather(text="晴", temp_c=25.0, icon="sunny")
    _cache_set("101010100", weather)
    result = _cache_get("101010100")
    assert result == weather


def test_cache_expiry() -> None:
    _CACHE.clear()
    weather = Weather(text="晴", temp_c=25.0, icon="sunny")
    _CACHE["loc"] = (time.monotonic() - 1, weather)  # 已过期
    assert _cache_get("loc") is None
    assert "loc" not in _CACHE


def test_cache_miss() -> None:
    _CACHE.clear()
    assert _cache_get("nonexistent") is None


# ---------- fetch_weather 集成 ----------


@pytest.mark.asyncio
async def test_fetch_weather_feature_disabled(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "feature_weather", False)
    monkeypatch.setattr(get_settings(), "weather_api_key", "test-key")
    _CACHE.clear()
    result = await fetch_weather(39.9, 116.4)
    assert result is None


@pytest.mark.asyncio
async def test_fetch_weather_no_key(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "feature_weather", True)
    monkeypatch.setattr(get_settings(), "weather_api_key", "")
    _CACHE.clear()
    result = await fetch_weather(39.9, 116.4)
    assert result is None


@pytest.mark.asyncio
async def test_fetch_weather_cache_hit(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_weather(monkeypatch)
    _CACHE.clear()

    cached = Weather(text="晴", temp_c=25.0, icon="sunny")
    _cache_set("101010100", cached)

    # geo 返回 location_id → 缓存命中 → 直接返回，不调 QWeather
    with patch(
        "app.services.weather_service._get_location_id",
        new_callable=AsyncMock,
        return_value="101010100",
    ):
        result = await fetch_weather(39.9, 116.4)

    assert result == cached


@pytest.mark.asyncio
async def test_fetch_weather_geo_fails_fallback_to_latlon(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _enable_weather(monkeypatch)
    _CACHE.clear()

    client, _ = _make_mock_client(_make_qweather_response("晴", "25"))

    with (
        patch(
            "app.services.weather_service._get_location_id",
            new_callable=AsyncMock,
            return_value=None,
        ),
        patch("app.services.weather_service.httpx.AsyncClient", return_value=client),
    ):
        result = await fetch_weather(39.9, 116.4)

    assert result == Weather(text="晴", temp_c=25.0, icon="sunny")
    # geo 失败时用 lat,lon 查询，不写缓存
    assert "39.9,116.4" not in _CACHE


@pytest.mark.asyncio
async def test_fetch_weather_qweather_failure_returns_none(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _enable_weather(monkeypatch)
    _CACHE.clear()

    with (
        patch(
            "app.services.weather_service._get_location_id",
            new_callable=AsyncMock,
            return_value="101010100",
        ),
        patch(
            "app.services.weather_service._fetch_from_qweather",
            new_callable=AsyncMock,
            return_value=None,
        ),
    ):
        result = await fetch_weather(39.9, 116.4)

    assert result is None


@pytest.mark.asyncio
async def test_fetch_weather_success_with_cache_write(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_weather(monkeypatch)
    _CACHE.clear()

    weather = Weather(text="多云", temp_c=22.0, icon="cloudy")

    with (
        patch(
            "app.services.weather_service._get_location_id",
            new_callable=AsyncMock,
            return_value="101010100",
        ),
        patch(
            "app.services.weather_service._fetch_from_qweather",
            new_callable=AsyncMock,
            return_value=weather,
        ),
    ):
        result = await fetch_weather(39.9, 116.4)

    assert result == weather
    assert "101010100" in _CACHE
    assert _cache_get("101010100") == weather
