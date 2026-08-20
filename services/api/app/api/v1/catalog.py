"""静态目录：主题皮肤与思绪标签（PRD 6.9 / 6.8）。

无需认证。纯读取，无外部依赖，不参与降级。
"""

from fastapi import APIRouter

from app.core.deps import Session
from app.schemas.common import TagPublic, ThemePublic

router = APIRouter(tags=["catalog"])


@router.get("/themes", response_model=list[ThemePublic])
async def list_themes(session: Session) -> list[ThemePublic]:
    """主题皮肤列表。P0 只有「夏」natsu。

    皮肤一旦被信件选定即永久绑定，此接口只提供可选项，不影响历史信件。
    """
    raise NotImplementedError


@router.get("/tags", response_model=list[TagPublic])
async def list_tags(session: Session) -> list[TagPublic]:
    """预置思绪标签，写信时可选 1–3 个。"""
    raise NotImplementedError
