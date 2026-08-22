"""随机漂流（PRD 6.3）。

**纯随机，禁止任何加权。** 不做同标签/兴趣/相似度排序——那与赛道「制造一点意外」
相悖，也违反 CLAUDE.md 红线 2。

收信 ≠ 已读：抽取只写 served_at 去重；开信（POST /v1/letters/{id}/read）才计 read_count。
"""

from fastapi import APIRouter

from app.core.deps import CurrentUser, Session
from app.schemas.letter import LetterPublic
from app.services import drift_service

router = APIRouter(prefix="/drift", tags=["drift"])


@router.get("/next", response_model=LetterPublic)
async def next_letter(session: Session, user_id: CurrentUser) -> LetterPublic:
    """抽一封非自己发、未被占用的公开漂流信。

    副作用：写 letter_reads（served_at，冷却去重）。已开封信永不再现；
    被丢弃的未开封信在冷却期后回池。池空时返回 404 drift_pool_empty。
    """
    letter = await drift_service.draw_next(session, user_id)
    return LetterPublic.from_letter(letter)
