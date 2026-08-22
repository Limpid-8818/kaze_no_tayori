"""就地发掘（PRD 6.4）。

与随机漂流并列的核心机制：让同地陌生人跨越时间对话。
收信 ≠ 已读：列表不标记已读，也不返回 viewer 已开封信。
"""

from typing import Annotated

from fastapi import APIRouter, Query

from app.core.config import get_settings
from app.core.deps import CurrentUser, Session
from app.schemas.common import Page
from app.schemas.letter import LetterPublic
from app.services import discover_service

router = APIRouter(prefix="/discover", tags=["discover"])


@router.get("", response_model=Page[LetterPublic])
async def discover_nearby(
    session: Session,
    user_id: CurrentUser,
    lat: Annotated[float, Query(ge=-90, le=90)],
    lon: Annotated[float, Query(ge=-180, le=180)],
    radius_m: Annotated[int | None, Query(ge=1, le=50000)] = None,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
) -> Page[LetterPublic]:
    """检索附近「留在这里」的公开信（不含自己已开过的）。

    走 ST_DWithin + GiST 索引；radius_m 缺省取 DISCOVER_RADIUS_M（默认 1000 米）。
    按 created_at DESC 排序——**不按热度**。
    """
    letters = await discover_service.discover_nearby(
        session,
        user_id=user_id,
        lat=lat,
        lon=lon,
        radius_m=radius_m if radius_m is not None else get_settings().discover_radius_m,
        limit=limit,
    )
    return Page(items=[LetterPublic.from_letter(x) for x in letters], next_cursor=None)
