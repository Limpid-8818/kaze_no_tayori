"""共鸣（PRD 6.6）。

✦ 共鸣**不是点赞**：只计数、不展示谁。
故意不提供「共鸣者列表」接口——任何能反查「谁共鸣了这封信」的能力都违反匿名铁律。
"""

from uuid import UUID

from fastapi import APIRouter

from app.core.deps import CurrentUser, Session
from app.schemas.common import ResonanceRequest, ResonanceResponse

router = APIRouter(tags=["resonance"])


@router.post("/letters/{letter_id}/resonance", response_model=ResonanceResponse)
async def resonate(
    letter_id: UUID, payload: ResonanceRequest, session: Session, user_id: CurrentUser
) -> ResonanceResponse:
    """一键 ✦：信获「已被 N 个陌生人接住」。

    幂等：同一人重复调用返回 200 且不重复计数（uq_resonance_once 保证）。
    可选附 ≤30 字匿名短句。
    """
    raise NotImplementedError
