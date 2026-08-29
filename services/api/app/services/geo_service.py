"""逆地理编码（模块⑦，可降级）。

坐标 → 城市级地点名。取不到就返回 None，由用户手填 place_label。
位置可控（PRD §8.1）：只返回省 · 市 · 区一级的纯名字（不带行政后缀），
不带街道/门牌——精确地址会削弱匿名，且可能暴露作者日常活动范围。

数据流：
    逆地理编码(lat,lon) → 内存缓存 → 城市级地址截断 → 返回 str | None
"""

from __future__ import annotations

import time

import httpx

from app.core.config import get_settings

# ---------- 内存缓存 ----------
# key = "lon,lat"（字符串，与高德参数顺序一致）
# value = (expiry_timestamp, address_str)
_CACHE: dict[str, tuple[float, str]] = {}
_CACHE_TTL_S = 3600  # 1 小时——地址变更不频繁，缓存久一点


def _cache_get(key: str) -> str | None:
    entry = _CACHE.get(key)
    if entry is None:
        return None
    expiry, address = entry
    if time.monotonic() >= expiry:
        del _CACHE[key]
        return None
    return address


def _cache_set(key: str, address: str) -> None:
    _CACHE[key] = (time.monotonic() + _CACHE_TTL_S, address)


def _normalize_host(host: str) -> str:
    """确保 host 带协议头，避免 httpx 报 UnsupportedProtocol。"""
    host = host.strip()
    if not host.startswith(("http://", "https://")):
        return f"https://{host}"
    return host


# 民族区域自治地的全名 → 短名（后缀剥离剥不掉中间的族名，逐一映射）
_AUTONOMOUS_SHORT = {
    "内蒙古自治区": "内蒙古",
    "广西壮族自治区": "广西",
    "西藏自治区": "西藏",
    "宁夏回族自治区": "宁夏",
    "新疆维吾尔自治区": "新疆",
}

_ADMIN_SUFFIXES = ("特别行政区", "自治区", "省", "自治州", "地区", "市", "区", "县", "旗")


def _strip_admin_suffix(name: str) -> str:
    """剥离行政后缀，只留名字：「辽宁省」→「辽宁」、「朝阳区」→「朝阳」。

    后缀剥离是逐级尝试（先长后短，「自治区」先于「省」）；剥完为空
    （名字本身就是后缀）或命中高德的「市辖区」占位值，返回空串，
    由调用方从拼接中剔除。
    """
    if name in _AUTONOMOUS_SHORT:
        return _AUTONOMOUS_SHORT[name]
    if name == "市辖区":
        return ""
    for suffix in _ADMIN_SUFFIXES:
        if name.endswith(suffix) and name != suffix:
            return name[: -len(suffix)]
    return name


def _truncate_to_city_level(address_component: dict) -> str:
    """将高德 addressComponent 截断为城市级地址。

    输出统一为「 · 」分隔的纯名字，不带行政后缀：

    - 直辖市（北京/上海/天津/重庆）的 province == city，此时 district
      就是有效粒度，返回「市 · 区」（如「北京 · 朝阳」），不是只有市级。
    - 常规城市返回「省 · 市 · 区」（如「辽宁 · 大连 · 中山」）。

    隐私控制（PRD §8.1）：去掉 township 及更细粒度，防止精确位置反推。
    """
    province = _strip_admin_suffix((address_component.get("province") or "").strip())
    city = _strip_admin_suffix((address_component.get("city") or "").strip())
    district = _strip_admin_suffix((address_component.get("district") or "").strip())

    # city 为空：港澳台或海外
    if not city:
        return province or district or ""

    # 直辖市：province == city（北京/上海/天津/重庆），district 是有效粒度
    if (address_component.get("province") or "").strip() == (
        address_component.get("city") or ""
    ).strip():
        parts = [city, district]
    else:
        # 常规城市：省 · 市 · 区
        parts = [province, city, district]
    return " · ".join(p for p in parts if p)


async def _fetch_reverse_geocode(lat: float, lon: float) -> str | None:
    """直接调用高德逆地理编码 API，返回城市级地址或 None。"""
    settings = get_settings()
    host = _normalize_host(settings.amap_api_host)
    url = f"{host}/v3/geocode/regeo"

    params = {
        "key": settings.amap_key,
        "location": f"{lon},{lat}",
        "extensions": "base",
        "output": "JSON",
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(url, params=params)
    except (OSError, httpx.TimeoutException, httpx.ConnectError, httpx.RequestError):
        return None

    if resp.status_code != 200:
        return None

    try:
        data = resp.json()
    except Exception:
        return None

    # 高德使用 infocode 判断成功/失败（部分接口用 status，部分用 infocode）
    # 逆地理编码：status="1" 且 infocode="10000" 表示成功
    if data.get("status") != "1" or data.get("infocode") != "10000":
        return None

    regeocode = data.get("regeocode") or {}
    address_component = regeocode.get("addressComponent") or {}

    return _truncate_to_city_level(address_component)


# ---------- 主函数 ----------


async def reverse_geocode(lat: float, lon: float) -> str | None:
    """将坐标反译为城市级地点名，如「北京 · 朝阳」。

    契约：FEATURE_GEOCODE=false、无 key、调用失败或超时 → 一律返回 None，
    **不抛异常**。取不到由用户手填 place_label，不影响写信流程。
    """
    settings = get_settings()
    if not settings.feature_geocode:
        return None
    if not settings.amap_key:
        return None

    cache_key = f"{lon:.5f},{lat:.5f}"
    cached = _cache_get(cache_key)
    if cached is not None:
        return cached

    try:
        address = await _fetch_reverse_geocode(lat, lon)
    except Exception:
        # 任何未预期的异常都降级为 None，不阻断主流程
        return None

    if not address:
        return None

    _cache_set(cache_key, address)
    return address
