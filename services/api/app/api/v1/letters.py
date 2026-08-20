"""写信与阅读（PRD 6.1）。

router 只做 HTTP ↔ service 转换，业务逻辑一律在 app/services/。
"""

from uuid import UUID

from fastapi import APIRouter

from app.core.deps import CurrentUser, OptionalUser, Session
from app.schemas.common import ReportRequest
from app.schemas.letter import LetterCreate, LetterOwned, LetterPublic

router = APIRouter(tags=["letters"])


@router.post("/letters", response_model=LetterOwned, status_code=201)
async def create_letter(
    payload: LetterCreate, session: Session, user_id: CurrentUser
) -> LetterOwned:
    """写一封信并投放。

    delivery_mode 必选：stay（锚定位置）或 drift（入随机漂流池）。
    提交后入审，默认 status=pending。
    """
    raise NotImplementedError


@router.get("/letters/{letter_id}", response_model=LetterPublic)
async def read_letter(letter_id: UUID, session: Session, user_id: OptionalUser) -> LetterPublic:
    """读单封公开信（回信溯源用）。非 public 一律 404。"""
    raise NotImplementedError


@router.post("/letters/{letter_id}/report", status_code=204)
async def report_letter(
    letter_id: UUID, payload: ReportRequest, session: Session, user_id: OptionalUser
) -> None:
    """举报（PRD §8.2）。入库待人工处理。"""
    raise NotImplementedError
