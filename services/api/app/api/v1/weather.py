"""天气查询（PRD 6.x，可降级）。

取不到就返回 null，不影响主流程。
"""

from fastapi import APIRouter

from app.schemas.letter import Weather
from app.services.weather_service import fetch_weather

router = APIRouter(prefix="/weather", tags=["weather"])


@router.get("/now", response_model=Weather | None)
async def get_current_weather(lat: float, lon: float) -> Weather | None:
    """按坐标查询当前天气。返回 null 表示取不到（降级）。"""
    return await fetch_weather(lat, lon)
