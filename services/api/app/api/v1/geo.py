"""逆地理编码（PRD §6.4 / §8.1，可降级）。

坐标 → 城市级地点名。取不到返回 null，不影响核心流程。
"""

from fastapi import APIRouter

from app.services.geo_service import reverse_geocode

router = APIRouter(prefix="/geo", tags=["geo"])


@router.get("/reverse")
async def reverse_geocode_endpoint(lat: float, lon: float) -> dict[str, str | None]:
    """按坐标查询城市级地点名。返回 null 表示取不到（降级）。"""
    place_label = await reverse_geocode(lat, lon)
    return {"place_label": place_label}
