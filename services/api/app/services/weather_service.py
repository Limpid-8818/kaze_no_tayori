"""天气（模块⑦，可降级）。

天气是「此情此景」的锚点之一（地点·时间·天气），不是必需品：
取不到就返回 None，信照样能写、能漂、能被接住。

数据流：
    逆地理编码(lat,lon) → LocationID → 内存缓存 → QWeather /v7/weather/now
    逆地理编码失败时降级直接用 lat,lon 查询（跳过缓存）。
"""

from __future__ import annotations

import time
from contextlib import suppress

import httpx

from app.core.config import get_settings
from app.schemas.letter import Weather

# ---------- 内存缓存 ----------
# key = QWeather LocationID（区县级唯一标识）
# value = (expiry_timestamp, Weather)
_CACHE: dict[str, tuple[float, Weather]] = {}
_CACHE_TTL_S = 600  # 10 分钟


def _cache_get(location_id: str) -> Weather | None:
    entry = _CACHE.get(location_id)
    if entry is None:
        return None
    expiry, weather = entry
    if time.monotonic() >= expiry:
        del _CACHE[location_id]
        return None
    return weather


def _cache_set(location_id: str, weather: Weather) -> None:
    _CACHE[location_id] = (time.monotonic() + _CACHE_TTL_S, weather)


# ---------- QWeather 映射 ----------

_ICON_MAP: dict[str, str] = {
    "sunny": ["晴"],
    "cloudy": ["云", "阴"],
    "rainy": ["雨", "雪", "雹", "雾", "霾"],
}


def _map_icon(text: str) -> str:
    """将 QWeather 天气描述映射为内部 icon 标识。"""
    for icon, keywords in _ICON_MAP.items():
        if any(kw in text for kw in keywords):
            return icon
    return "cloudy"


def _normalize_host(host: str) -> str:
    """确保 host 带协议头，避免 httpx 报 UnsupportedProtocol。"""
    host = host.strip()
    if not host.startswith(("http://", "https://")):
        return f"https://{host}"
    return host


async def _get_location_id(lat: float, lon: float) -> str | None:
    """调用 QWeather GeoAPI 获取 LocationID，供天气 API 查询和缓存使用。

    返回区县级 LocationID（如 "101010100"）。失败时返回 None，不抛异常。
    """
    settings = get_settings()
    if not settings.weather_api_key:
        return None

    host = _normalize_host(settings.weather_api_host)
    url = f"{host}/geo/v2/city/lookup"
    params = {
        "location": f"{lon},{lat}",
        "lang": "zh",
    }
    headers = {
        "X-QW-Api-Key": settings.weather_api_key,
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(url, params=params, headers=headers)
    except (OSError, httpx.TimeoutException, httpx.ConnectError, httpx.RequestError):
        return None

    if resp.status_code != 200:
        return None

    try:
        data = resp.json()
    except Exception:
        return None

    if data.get("code") != "200":
        return None

    locations = data.get("location") or []
    if not locations:
        return None

    return locations[0].get("id") or None


# ---------- 主函数 ----------


async def fetch_weather(lat: float, lon: float) -> Weather | None:
    """取当前天气。

    契约：FEATURE_WEATHER=false、无 key、调用失败或超时 → 一律返回 None，
    **不抛异常**。落点少一个天气字段，不影响核心循环。
    """
    settings = get_settings()
    if not settings.feature_weather:
        return None
    if not settings.weather_api_key:
        return None

    # 1. 尝试获取 LocationID（区县级）
    location_id: str | None = None
    try:
        location_id = await _get_location_id(lat, lon)
    except Exception:
        # geo 未实现或失败时降级，不阻断主流程
        location_id = None

    # 2. 如果有 LocationID，优先查缓存
    use_location_id = False
    if location_id:
        cached = _cache_get(location_id)
        if cached is not None:
            return cached
        use_location_id = True

    # 3. 构建查询参数
    # 有 LocationID 时用它（更精确、可缓存），否则降级用 lat,lon
    location_param = location_id if use_location_id else f"{lon},{lat}"

    # 4. 调 QWeather
    try:
        weather = await _fetch_from_qweather(location_param)
    except Exception:
        return None

    if weather is None:
        return None

    # 5. 有 LocationID 时才写缓存
    if use_location_id and location_id:
        _cache_set(location_id, weather)

    return weather


async def _fetch_from_qweather(location: str) -> Weather | None:
    """直接调用 QWeather，返回 Weather 或 None。"""
    settings = get_settings()
    host = _normalize_host(settings.weather_api_host)
    url = f"{host}/v7/weather/now"

    params = {
        "location": location,
        "lang": "zh",
    }

    headers = {
        "X-QW-Api-Key": settings.weather_api_key,
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(url, params=params, headers=headers)
    except (OSError, httpx.TimeoutException, httpx.ConnectError, httpx.RequestError):
        return None

    if resp.status_code != 200:
        return None

    try:
        data = resp.json()
    except Exception:
        return None

    if data.get("code") != "200":
        return None

    now = data.get("now") or {}
    temp_str = now.get("temp", "")
    text = now.get("text", "")

    temp_c: float | None = None
    if temp_str:
        with suppress(ValueError, TypeError):
            temp_c = float(temp_str)

    if not text:
        return None

    return Weather(
        text=text,
        temp_c=temp_c,
        icon=_map_icon(text),
    )
