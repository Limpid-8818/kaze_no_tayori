"""AI 润色与短诗（PRD 6.2，可关）。

**AI 是桥不是枪手**：润色保留原意、用户可选采纳；整体可关闭且不影响主流程。
FEATURE_AI=false 时返回 503 feature_disabled，前端据此降级为纯手动写信——
这是降级，不是错误。
"""

from fastapi import APIRouter

from app.core.deps import CurrentUser
from app.schemas.common import PoemResponse, PolishRequest, PolishResponse

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/polish", response_model=PolishResponse)
async def polish(payload: PolishRequest, user_id: CurrentUser) -> PolishResponse:
    """润色正文，保留原意。用户可选采纳。"""
    raise NotImplementedError


@router.post("/poem", response_model=PoemResponse)
async def poem(payload: PolishRequest, user_id: CurrentUser) -> PoemResponse:
    """从正文提取意象生成 ≤4 行短诗，与正文同屏展示。"""
    raise NotImplementedError
