"""本人视角：我的信、抄本、通知（PRD 6.10 / 6.5 / 8.1）。

这是唯一允许返回 LetterOwned 的路径前缀，且必须带 JWT。
"""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Query

from app.core.deps import CurrentUser, Session
from app.schemas.common import NotificationPublic, Page, ScripbookAddRequest
from app.schemas.letter import LetterOwned, LetterPublic
from app.services import letter_service, notification_service, resonance_service

router = APIRouter(prefix="/me", tags=["me"])


# ---------- 我的信 ----------
@router.get("/letters", response_model=Page[LetterOwned])
async def my_letters(
    session: Session,
    user_id: CurrentUser,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
) -> Page[LetterOwned]:
    """我写下的信，含审核中（pending）的。"""
    letters = await letter_service.list_owned_letters(session, user_id, limit)
    items = [LetterOwned.from_letter(letter, lat=letter.lat, lon=letter.lon) for letter in letters]
    return Page(items=items, next_cursor=None)


@router.delete("/letters/{letter_id}", status_code=204)
async def take_down_letter(letter_id: UUID, session: Session, user_id: CurrentUser) -> None:
    """下架自己的信（→ taken_down）。非硬删，保留回信链完整性（PRD §8.1 可删除）。"""
    await letter_service.take_down(session, letter_id, user_id)


# ---------- 抄本 ----------
@router.get("/scripbook", response_model=Page[LetterPublic])
async def my_scripbook(
    session: Session,
    user_id: CurrentUser,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
) -> Page[LetterPublic]:
    """我的抄本。个人行为，不计入公开互动。"""
    letters = await resonance_service.list_scripbook(session, user_id, limit)
    items = [LetterPublic.from_letter(letter) for letter in letters]
    return Page(items=items, next_cursor=None)


@router.post("/scripbook", status_code=204)
async def add_to_scripbook(
    payload: ScripbookAddRequest, session: Session, user_id: CurrentUser
) -> None:
    await resonance_service.add_to_scripbook(session, payload.letter_id, user_id, payload.note)


@router.delete("/scripbook/{letter_id}", status_code=204)
async def remove_from_scripbook(letter_id: UUID, session: Session, user_id: CurrentUser) -> None:
    await resonance_service.remove_from_scripbook(session, letter_id, user_id)


# ---------- 通知 ----------
@router.get("/notifications", response_model=Page[NotificationPublic])
async def my_notifications(
    session: Session,
    user_id: CurrentUser,
    unread_only: bool = False,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
) -> Page[NotificationPublic]:
    """回信告知列表。P0 只做拉取，不做推送（前端：开页拉取 + 回前台拉 unread_only）。"""
    rows = await notification_service.list_notifications(session, user_id, unread_only, limit)
    items = [
        NotificationPublic(
            id=str(n.id),
            type=n.type,
            letter_id=str(n.letter_id),
            parent_letter_id=str(n.parent_letter_id),
            parent_place_label=place_label,
            is_read=n.is_read,
            created_at=n.created_at.isoformat(),
        )
        for n, place_label in rows
    ]
    return Page(items=items, next_cursor=None)


@router.post("/notifications/{notification_id}/read", status_code=204)
async def mark_notification_read(
    notification_id: UUID, session: Session, user_id: CurrentUser
) -> None:
    await notification_service.mark_read(session, user_id, notification_id)
