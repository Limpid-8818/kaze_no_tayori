"""共鸣与抄本（模块④）。

✦ 共鸣不是点赞：只计数、不展示谁、不提供共鸣者查询。
抄本是个人行为，不计入公开互动。
"""

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.letter import Letter


async def resonate(session: AsyncSession, letter_id: UUID, user_id: UUID, note: str | None) -> int:
    """一键 ✦，返回新的 resonance_count。

    契约：幂等。靠 uq_resonance_once 约束，冲突时不重复计数、返回当前值而非报错
    （用 ON CONFLICT DO NOTHING）。note 有值时 voice_count 也 +1。
    """
    raise NotImplementedError


async def add_to_scripbook(
    session: AsyncSession, letter_id: UUID, user_id: UUID, note: str | None
) -> None:
    """收进抄本。幂等（PK 冲突忽略），原信 saved_count + 1。"""
    raise NotImplementedError


async def remove_from_scripbook(session: AsyncSession, letter_id: UUID, user_id: UUID) -> None:
    """从抄本移除，saved_count - 1（不小于 0）。"""
    raise NotImplementedError


async def list_scripbook(session: AsyncSession, user_id: UUID, limit: int) -> list[Letter]:
    """我的抄本，按 added_at DESC。"""
    raise NotImplementedError
