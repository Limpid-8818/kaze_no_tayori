"""地理发掘（模块①）：ST_DWithin 附近检索。

与随机漂流并列的核心机制：让同地陌生人跨越时间对话。
收信 ≠ 已读：列表不标记已读，也不返回 viewer 已开封信。
"""

from uuid import UUID

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.enums import DeliveryMode, LetterStatus
from app.models.letter import Letter


async def discover_nearby(
    session: AsyncSession,
    user_id: UUID,
    lat: float,
    lon: float,
    radius_m: int,
    limit: int,
) -> list[Letter]:
    """检索附近「留在这里」的公开信，不含 viewer 已开封的（收信≠已读：
    列表浏览不标记已读，开信才标记；已开过的不再出现在列表里）。

    契约 SQL 形状：
       WHERE status='public' AND delivery_mode='stay'
         AND ST_DWithin(location, ST_MakePoint(:lon,:lat)::geography, :radius_m)
         AND NOT EXISTS (SELECT 1 FROM letter_reads
                         WHERE user_id=:me AND letter_id=letters.id
                           AND opened_at IS NOT NULL)
       ORDER BY created_at DESC

    location 是 Geography 类型，radius_m 直接以米为单位，走 GiST 索引。
    排序只按时间——**不按热度/距离**。
    """
    # 用裸 SQL 避免 SQLAlchemy 对 WKTElement 的渲染问题
    result = await session.execute(
        text(
            """
            SELECT id FROM letters
            WHERE status = :status
              AND delivery_mode = :mode
              AND ST_DWithin(location, ST_MakePoint(:lon, :lat)::geography, :radius)
              AND NOT EXISTS (
                  SELECT 1 FROM letter_reads
                  WHERE user_id = :user_id
                    AND letter_id = letters.id
                    AND opened_at IS NOT NULL
              )
            ORDER BY created_at DESC
            LIMIT :limit
            """
        ),
        {
            "status": LetterStatus.PUBLIC,
            "mode": DeliveryMode.STAY.value,
            "lon": lon,
            "lat": lat,
            "radius": radius_m,
            "user_id": str(user_id),
            "limit": limit,
        },
    )
    ids = [row.id for row in result.fetchall()]
    if not ids:
        return []
    # 根据 id 列表取 ORM 对象（保持返回 Letter 列表的契约）
    result = await session.execute(
        select(Letter).where(Letter.id.in_(ids)).order_by(Letter.created_at.desc())
    )
    return list(result.scalars().all())
