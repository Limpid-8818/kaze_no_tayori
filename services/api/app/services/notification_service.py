"""通知（模块③的读取侧）：回信告知的拉取与已读标记。

P0 只做拉取，不做推送（契约锁定）。原作者不是回信的收件人——
通知只指向公开回信，读者侧无任何可达作者的反向通道。
"""

from datetime import datetime
from uuid import UUID

from sqlalchemy import CursorResult, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFound
from app.models.letter import Letter
from app.models.notification import Notification


async def list_notifications(
    session: AsyncSession, user_id: UUID, unread_only: bool, limit: int
) -> list[tuple[Notification, str | None, datetime | None]]:
    """本人通知列表，按 created_at DESC。

    返回 (notification, parent_place_label, parent_created_at)：NotificationPublic
    需要「你于 {地点} 写的那封信」的地名与原信写信日期，模型无此列，JOIN 原信取。
    """
    query = (
        select(Notification, Letter.place_label, Letter.created_at)
        .outerjoin(Letter, Notification.parent_letter_id == Letter.id)
        .where(Notification.user_id == user_id)
        .order_by(Notification.created_at.desc())
        .limit(limit)
    )
    if unread_only:
        query = query.where(Notification.is_read.is_(False))
    result = await session.execute(query)
    return [(row[0], row[1], row[2]) for row in result.all()]


async def mark_read(session: AsyncSession, user_id: UUID, notification_id: UUID) -> None:
    """标记已读。rowcount=0 视为不存在——不区分「不存在」与「不是你的」，
    避免泄漏他人通知的存在性。幂等：已读再标仍是 204。"""
    from typing import cast

    result = cast(
        CursorResult,
        await session.execute(
            update(Notification)
            .where(Notification.id == notification_id, Notification.user_id == user_id)
            .values(is_read=True)
        ),
    )
    if result.rowcount == 0:
        raise NotFound("通知不存在")
