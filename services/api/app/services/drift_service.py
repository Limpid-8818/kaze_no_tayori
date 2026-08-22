"""漂流分发（模块①）：随机抽取。

**纯随机，禁止加权**（CLAUDE.md 红线 2 + 赛道「制造一点意外」）。

收信 ≠ 已读：抽取只写 served_at（去重），read_count 在开信
（POST /v1/letters/{id}/read）时才自增。
"""

from datetime import UTC, datetime, timedelta
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import DriftPoolEmpty
from app.models.enums import DeliveryMode, LetterStatus
from app.models.letter import Letter
from app.models.letter_read import LetterRead


def _serve_cutoff() -> datetime:
    """送达冷却起点：冷却期内的未开封信不重发（被丢弃的信过后回池）。"""
    return datetime.now(UTC) - timedelta(seconds=get_settings().drift_serve_cooldown_s)


async def draw_next(session: AsyncSession, user_id: UUID) -> Letter:
    """抽一封非自己发、未被占用的 public+drift 信。

    排除条件（收信≠已读）：
      - 已开封（letter_reads.opened_at 非空）→ 永不再现
      - 冷却期内送达过（served_at > now()-cooldown 且未开封）→ 暂不复现
        （丢弃的未开封信在冷却后回到池里，未来仍可漂来）
    副作用：写 letter_reads(served_at)。**不动 read_count**。
    池空抛 DriftPoolEmpty。
    """
    excluded = (
        select(LetterRead.letter_id)
        .where(
            LetterRead.user_id == user_id,
            (LetterRead.opened_at.is_not(None)) | (LetterRead.served_at > _serve_cutoff()),
        )
        .scalar_subquery()
    )
    result = await session.execute(
        select(Letter)
        .where(
            Letter.status == LetterStatus.PUBLIC,
            Letter.delivery_mode == DeliveryMode.DRIFT,
            (Letter.owner_user_id.is_(None)) | (Letter.owner_user_id != user_id),
            Letter.id.not_in(excluded),
        )
        .order_by(func.random())
        .limit(1)
    )
    letter = result.scalar_one_or_none()
    if letter is None:
        raise DriftPoolEmpty("此刻还没有漂来的信")

    await session.execute(
        pg_insert(LetterRead).values(letter_id=letter.id, user_id=user_id).on_conflict_do_nothing()
    )
    await session.flush()
    return letter
