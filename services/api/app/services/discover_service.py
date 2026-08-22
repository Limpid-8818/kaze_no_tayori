"""地理发掘（模块①）：ST_DWithin 附近检索。

与随机漂流并列的核心机制：让同地陌生人跨越时间对话。
"""

from uuid import UUID

from geoalchemy2 import WKTElement
from sqlalchemy import exists, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.enums import DeliveryMode, LetterStatus
from app.models.letter import Letter
from app.models.letter_read import LetterRead


async def discover_nearby(
    session: AsyncSession,
    user_id: UUID,
    lat: float,
    lon: float,
    radius_m: int,
    limit: int,
) -> list[Letter]:
    """检索附近「留在这里」的公开信，不含 viewer 已开封的（收信≠已读：
    列表浏览不标记，开信才标记；已开过的不再出现在列表里）。

    契约 SQL 形状：
        WHERE status='public' AND delivery_mode='stay'
          AND ST_DWithin(location, ST_MakePoint(:lon,:lat)::geography, :radius_m)
          AND NOT EXISTS (SELECT 1 FROM letter_reads
                          WHERE user_id=:me AND letter_id=letters.id
                            AND opened_at IS NOT NULL)
        ORDER BY created_at DESC

    location 是 Geography 类型，radius_m 直接以米为单位，走 GiST 索引。
    排序只按时间——**不按距离热度、不按互动数**。
    """
    point = WKTElement(f"POINT({lon} {lat})", srid=4326, extended=True)
    opened = exists().where(
        LetterRead.letter_id == Letter.id,
        LetterRead.user_id == user_id,
        LetterRead.opened_at.is_not(None),
    )
    result = await session.execute(
        select(Letter)
        .where(
            Letter.status == LetterStatus.PUBLIC,
            Letter.delivery_mode == DeliveryMode.STAY,
            func.ST_DWithin(Letter.location, point, radius_m),
            ~opened,
        )
        .order_by(Letter.created_at.desc())
        .limit(limit)
    )
    return list(result.scalars().all())
