"""就地发掘（PRD 6.4）。

与随机漂流并列的核心机制：让同地陌生人跨越时间对话。
"""

from typing import Annotated

from fastapi import APIRouter, Query

from app.core.deps import CurrentUser, Session
from app.schemas.common import Page
from app.schemas.letter import LetterPublic

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
    """检索附近「留在这里」的公开信。

    走 ST_DWithin + GiST 索引；radius_m 缺省取 DISCOVER_RADIUS_M（默认 1000 米）。
    按 created_at DESC 排序——**不按热度**。
    """
    raise NotImplementedError
