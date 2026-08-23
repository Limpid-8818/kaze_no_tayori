"""地理编码模块测试。

覆盖：正常返回、feature 禁用、无 key、网络异常、高德错误码、
缓存命中、缓存过期、隐私截断（省市区、港澳台回退）。
"""

from __future__ import annotations

import time
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.core.config import get_settings
from app.services.geo_service import (
    _CACHE,
    _cache_get,
    _cache_set,
    _fetch_reverse_geocode,
    _truncate_to_city_level,
    reverse_geocode,
)

# ---------- 辅助 ----------


def _enable_geocode(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "feature_geocode", True)
    monkeypatch.setattr(get_settings(), "amap_key", "test-key")
    monkeypatch.setattr(get_settings(), "amap_api_host", "https://restapi.amap.com")


def _make_amap_response(address_component: dict, infocode: str = "10000") -> dict:
    return {
        "status": "1",
        "infocode": infocode,
        "regeocode": {
            "addressComponent": address_component,
        },
    }


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


# ---------- _truncate_to_city_level ----------


@pytest.mark.parametrize(
    ("component", "expected"),
    [
        # 直辖市：province == city，district 是有效粒度 → 市+区
        (
            {"province": "北京市", "city": "北京市", "district": "朝阳区", "township": "阜通街道"},
            "北京市朝阳区",
        ),
        # 直辖市：空 district 时回退市级
        (
            {"province": "北京市", "city": "北京市", "district": "", "township": ""},
            "北京市",
        ),
        # 省 + 市 + 区（非直辖市）
        (
            {
                "province": "辽宁省",
                "city": "大连市",
                "district": "中山区",
                "township": "海军广场街道",
            },
            "辽宁省大连市中山区",
        ),
        # city 为空（港澳台）→ 回退 province
        (
            {"province": "香港特别行政区", "city": "", "district": "中西区", "township": "中环"},
            "香港特别行政区",
        ),
        # 全空
        ({"province": "", "city": "", "district": "", "township": ""}, ""),
    ],
)
def test_truncate_to_city_level(component: dict, expected: str) -> None:
    assert _truncate_to_city_level(component) == expected


# ---------- _fetch_reverse_geocode ----------


@pytest.mark.asyncio
async def test_fetch_reverse_geocode_success(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_geocode(monkeypatch)
    client, _ = _make_mock_client(
        _make_amap_response({"province": "北京市", "city": "北京市", "district": "朝阳区"})
    )
    with patch("app.services.geo_service.httpx.AsyncClient", return_value=client):
        result = await _fetch_reverse_geocode(39.918, 116.487)
    assert result == "北京市朝阳区"


@pytest.mark.asyncio
async def test_fetch_reverse_geocode_feature_disabled(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "feature_geocode", False)
    monkeypatch.setattr(get_settings(), "amap_key", "test-key")
    result = await _fetch_reverse_geocode(39.918, 116.487)
    assert result is None


@pytest.mark.asyncio
async def test_fetch_reverse_geocode_no_key(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "feature_geocode", True)
    monkeypatch.setattr(get_settings(), "amap_key", "")
    result = await _fetch_reverse_geocode(39.918, 116.487)
    assert result is None


@pytest.mark.asyncio
async def test_fetch_reverse_geocode_network_error(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_geocode(monkeypatch)
    with patch("app.services.geo_service.httpx.AsyncClient", side_effect=OSError("network down")):
        result = await _fetch_reverse_geocode(39.918, 116.487)
    assert result is None


@pytest.mark.asyncio
async def test_fetch_reverse_geocode_non_200(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_geocode(monkeypatch)
    client, _ = _make_mock_client(_make_amap_response({}))
    client.get.return_value.status_code = 500
    with patch("app.services.geo_service.httpx.AsyncClient", return_value=client):
        result = await _fetch_reverse_geocode(39.918, 116.487)
    assert result is None


@pytest.mark.asyncio
async def test_fetch_reverse_geocode_api_error_status(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_geocode(monkeypatch)
    client, _ = _make_mock_client({"status": "0", "infocode": "10001", "info": "INVALID_USER_KEY"})
    with patch("app.services.geo_service.httpx.AsyncClient", return_value=client):
        result = await _fetch_reverse_geocode(39.918, 116.487)
    assert result is None


@pytest.mark.asyncio
async def test_fetch_reverse_geocode_missing_address_component(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _enable_geocode(monkeypatch)
    client, _ = _make_mock_client(_make_amap_response({}))
    with patch("app.services.geo_service.httpx.AsyncClient", return_value=client):
        result = await _fetch_reverse_geocode(39.918, 116.487)
    assert result == ""


# ---------- 缓存 ----------


def test_cache_set_and_get() -> None:
    _CACHE.clear()
    _cache_set("116.48700,39.91800", "北京市朝阳区")
    result = _cache_get("116.48700,39.91800")
    assert result == "北京市朝阳区"


def test_cache_expiry() -> None:
    _CACHE.clear()
    _CACHE["116.48700,39.91800"] = (time.monotonic() - 1, "address")  # 已过期
    assert _cache_get("116.48700,39.91800") is None
    assert "116.48700,39.91800" not in _CACHE


def test_cache_miss() -> None:
    _CACHE.clear()
    assert _cache_get("nonexistent") is None


# ---------- reverse_geocode 集成 ----------


@pytest.mark.asyncio
async def test_reverse_geocode_feature_disabled(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "feature_geocode", False)
    monkeypatch.setattr(get_settings(), "amap_key", "test-key")
    _CACHE.clear()
    result = await reverse_geocode(39.918, 116.487)
    assert result is None


@pytest.mark.asyncio
async def test_reverse_geocode_no_key(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(get_settings(), "feature_geocode", True)
    monkeypatch.setattr(get_settings(), "amap_key", "")
    _CACHE.clear()
    result = await reverse_geocode(39.918, 116.487)
    assert result is None


@pytest.mark.asyncio
async def test_reverse_geocode_cache_hit(monkeypatch: pytest.MonkeyPatch) -> None:
    _CACHE.clear()

    _cache_set("116.48700,39.91800", "北京市朝阳区")

    # 在 geo_service 模块层面 mock get_settings，避开 @lru_cache 副作用
    mock_settings = MagicMock()
    mock_settings.feature_geocode = True
    mock_settings.amap_key = "test-key"
    with (
        patch("app.services.geo_service.get_settings", return_value=mock_settings),
        patch(
            "app.services.geo_service._fetch_reverse_geocode",
            new_callable=AsyncMock,
            side_effect=AssertionError("_fetch_reverse_geocode 不应被调用"),
        ),
    ):
        result = await reverse_geocode(39.918, 116.487)

    assert result == "北京市朝阳区"


@pytest.mark.asyncio
async def test_reverse_geocode_cache_expired(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_geocode(monkeypatch)
    _CACHE.clear()

    _CACHE["116.487,39.918"] = (time.monotonic() - 1, "旧地址")

    client, _ = _make_mock_client(
        _make_amap_response({"province": "北京市", "city": "北京市", "district": "海淀区"})
    )
    with patch("app.services.geo_service.httpx.AsyncClient", return_value=client):
        result = await reverse_geocode(39.918, 116.487)

    assert result == "北京市海淀区"


@pytest.mark.asyncio
async def test_reverse_geocode_network_error(monkeypatch: pytest.MonkeyPatch) -> None:
    _enable_geocode(monkeypatch)
    _CACHE.clear()

    with patch(
        "app.services.geo_service._fetch_reverse_geocode",
        new_callable=AsyncMock,
        side_effect=OSError("network down"),
    ):
        result = await reverse_geocode(39.918, 116.487)

    assert result is None


@pytest.mark.asyncio
async def test_reverse_geocode_success_with_cache_write(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _CACHE.clear()

    client, _ = _make_mock_client(
        _make_amap_response({"province": "辽宁省", "city": "大连市", "district": "中山区"})
    )

    mock_settings = MagicMock()
    mock_settings.feature_geocode = True
    mock_settings.amap_key = "test-key"
    with (
        patch("app.services.geo_service.get_settings", return_value=mock_settings),
        patch("app.services.geo_service.httpx.AsyncClient", return_value=client),
    ):
        result = await reverse_geocode(39.918, 116.487)

    assert result == "辽宁省大连市中山区"
    assert _cache_get("116.48700,39.91800") == "辽宁省大连市中山区"
