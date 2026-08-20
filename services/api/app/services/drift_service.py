"""漂流分发（模块①）：随机抽取。

**纯随机，禁止加权**（CLAUDE.md 红线 2 + 赛道「制造一点意外」）。
"""

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.letter import Letter


async def draw_next(session: AsyncSession, user_id: UUID) -> Letter:
    """抽一封非自己发、未读过的 public+drift 信。

    契约 SQL 形状：
        WHERE status='public' AND delivery_mode='drift'
          AND (owner_user_id IS NULL OR owner_user_id <> :me)
          AND id NOT IN (SELECT letter_id FROM letter_reads WHERE user_id=:me)
        ORDER BY random() LIMIT 1

    副作用：写 letter_reads + read_count+1。
    池空抛 DriftPoolEmpty。
    """
    raise NotImplementedError
