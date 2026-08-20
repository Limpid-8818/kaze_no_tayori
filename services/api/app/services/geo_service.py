"""逆地理编码（模块⑦，可降级）。

坐标 → 地点名。取不到就返回 None，由用户手填 place_label。
位置可控（PRD §8.1）：地点名倾向城市级，不要精确到门牌——精确地址会削弱匿名。
"""

from app.core.config import get_settings


async def reverse_geocode(lat: float, lon: float) -> str | None:
    """返回城市级地点名，如「Tokyo」「大连」。

    契约：FEATURE_GEOCODE=false、无 key、调用失败或超时 → 返回 None，**不抛异常**。
    """
    if not get_settings().feature_geocode:
        return None
    raise NotImplementedError
