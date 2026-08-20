"""回信（PRD 6.5）。

**回信是独立作品，不是私信。** 它是 letters 表里一条独立行，靠 parent_letter_id 溯源；
原作者只是「获知」，不是收件人，也无法回复。禁止在此之上建 DM / conversation / thread。
"""

from uuid import UUID

from fastapi import APIRouter

from app.core.deps import CurrentUser, OptionalUser, Session
from app.schemas.common import Page
from app.schemas.letter import LetterCreate, LetterOwned, LetterPublic

router = APIRouter(tags=["replies"])


@router.post("/letters/{letter_id}/replies", response_model=LetterOwned, status_code=201)
async def create_reply(
    letter_id: UUID, payload: LetterCreate, session: Session, user_id: CurrentUser
) -> LetterOwned:
    """回以一封信：新建独立信件，parent_letter_id = letter_id。

    副作用：
    - 原信 reply_count + 1
    - 原信 owner_user_id 非空 → 插入 Notification(type=reply)
    - 原信无 owner（纯过客所写）→ 静默跳过通知，回信照样公开
    """
    raise NotImplementedError


@router.get("/letters/{letter_id}/replies", response_model=Page[LetterPublic])
async def list_replies(
    letter_id: UUID, session: Session, user_id: OptionalUser
) -> Page[LetterPublic]:
    """该信的公开回信列表，形成弱链接作品链。"""
    raise NotImplementedError
