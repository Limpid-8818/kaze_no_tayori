"""回信与通知（模块③）：parent 溯源 + 原作者告知。

**回信是独立作品，不是私信。** 原作者只是「获知」，不是收件人。
"""

from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.enums import LetterStatus, NotificationType
from app.models.letter import Letter
from app.models.notification import Notification
from app.schemas.letter import LetterCreate
from app.services import letter_service


async def create_reply(
    session: AsyncSession,
    parent_letter_id: UUID,
    payload: LetterCreate,
    owner_user_id: UUID,
) -> Letter:
    """回以一封信。

    契约：
    1. 复用 letter_service.create_letter 建一封**独立**信件，parent_letter_id 预置
    2. 原信 reply_count + 1
    3. 原信 owner_user_id 非空 → notify_original_author
    4. 原信无 owner（纯过客所写）→ 静默跳过通知，回信照样公开
       （PRD 6.5 可达性边界）
    """
    parent = await letter_service.get_public_letter(session, parent_letter_id)

    reply = await letter_service.create_letter(
        session, payload, owner_user_id=owner_user_id, parent_letter_id=parent.id
    )
    await session.execute(
        update(Letter)
        .where(Letter.id == parent.id)
        .values(reply_count=Letter.reply_count + 1)
        .execution_options(synchronize_session=False)
    )
    await notify_original_author(session, parent, reply)
    return reply


async def notify_original_author(
    session: AsyncSession, parent_letter: Letter, reply_letter: Letter
) -> Notification | None:
    """告知原作者「你于 {地点} 写的那封信，收到一封回信 ✦」。

    owner 为空时返回 None——不报错，这是正常的可达性边界。
    原作者不是回信的收件人：通知只指向公开回信，无法回复。
    """
    if parent_letter.owner_user_id is None:
        return None
    notification = Notification(
        user_id=parent_letter.owner_user_id,
        type=NotificationType.REPLY,
        letter_id=reply_letter.id,
        parent_letter_id=parent_letter.id,
    )
    session.add(notification)
    await session.flush()
    return notification


async def list_replies(session: AsyncSession, parent_letter_id: UUID, limit: int) -> list[Letter]:
    """该信的公开回信列表，形成弱链接作品链。"""
    result = await session.execute(
        select(Letter)
        .where(
            Letter.parent_letter_id == parent_letter_id,
            Letter.status == LetterStatus.PUBLIC,
        )
        .order_by(Letter.created_at.desc())
        .limit(limit)
    )
    return list(result.scalars().all())
