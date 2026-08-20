"""天气（模块⑦，可降级）。

天气是「此情此景」的锚点之一（地点·时间·天气），不是必需品：
取不到就返回 None，信照样能写、能漂、能被接住。
"""

from app.core.config import get_settings
from app.schemas.letter import Weather


async def fetch_weather(lat: float, lon: float) -> Weather | None:
    """取当前天气。

    契约：FEATURE_WEATHER=false、无 key、调用失败或超时 → 一律返回 None，
    **不抛异常**。落点少一个天气字段，不影响核心循环。
    """
    if not get_settings().feature_weather:
        return None
    raise NotImplementedError
