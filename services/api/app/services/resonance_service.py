"""共鸣与抄本（模块④）。

✦ 共鸣不是点赞：只计数、不展示谁、不提供共鸣者查询。
抄本是个人行为，不计入公开互动。
"""

from typing import cast
from uuid import UUID

from sqlalchemy import CursorResult, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.letter import Letter
from app.models.resonance import ResonanceLog
from app.services import letter_service


async def resonate(session: AsyncSession, letter_id: UUID, user_id: UUID, note: str | None) -> int:
    """一键 ✦，返回新的 resonance_count。

    契约：幂等。靠 uq_resonance_once 约束，冲突时不重复计数、返回当前值而非报错
    （用 ON CONFLICT DO NOTHING）。note 有值时 voice_count 也 +1（同样只加一次）。
    """
    letter = await letter_service.get_public_letter(session, letter_id)

    inserted = cast(
        CursorResult,
        await session.execute(
            pg_insert(ResonanceLog)
            .values(letter_id=letter_id, user_id=user_id, note=note)
            .on_conflict_do_nothing(constraint="uq_resonance_once")
        ),
    )
    if inserted.rowcount == 1:
        values = {"resonance_count": Letter.resonance_count + 1}
        if note:
            values["voice_count"] = Letter.voice_count + 1
        # synchronize_session=evaluate 会把 +1 同步回内存对象，再 +1 就翻倍——关掉
        await session.execute(
            update(Letter)
            .where(Letter.id == letter_id)
            .values(**values)
            .execution_options(synchronize_session=False)
        )
        return letter.resonance_count + 1

    # 重复共鸣：静默返回当前计数（letter ORM 对象可能未刷新，回查一次）
    refreshed = await letter_service.get_public_letter(session, letter_id)
    return refreshed.resonance_count


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
