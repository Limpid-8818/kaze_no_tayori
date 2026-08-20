"""随机漂流（PRD 6.3）。

**纯随机，禁止任何加权。** 不做同标签/兴趣/相似度排序——那与赛道「制造一点意外」
相悖，也违反 CLAUDE.md 红线 2。
"""

from fastapi import APIRouter

from app.core.deps import CurrentUser, Session
from app.schemas.letter import LetterPublic

router = APIRouter(prefix="/drift", tags=["drift"])


@router.get("/next", response_model=LetterPublic)
async def next_letter(session: Session, user_id: CurrentUser) -> LetterPublic:
    """抽一封非自己发、未读过的公开漂流信。

    副作用：写 letter_reads + read_count+1。
    池空时返回 404 drift_pool_empty。
    """
    raise NotImplementedError
