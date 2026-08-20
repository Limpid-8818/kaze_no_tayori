"""地理发掘（模块①）：ST_DWithin 附近检索。

与随机漂流并列的核心机制：让同地陌生人跨越时间对话。
"""

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.letter import Letter


async def discover_nearby(
    session: AsyncSession,
    lat: float,
    lon: float,
    radius_m: int,
    limit: int,
) -> list[Letter]:
    """检索附近「留在这里」的公开信。

    契约 SQL 形状：
        WHERE status='public' AND delivery_mode='stay'
          AND ST_DWithin(location, ST_MakePoint(:lon,:lat)::geography, :radius_m)
        ORDER BY created_at DESC

    location 是 Geography 类型，radius_m 直接以米为单位，走 GiST 索引。
    排序只按时间——**不按距离热度、不按互动数**。
    """
    raise NotImplementedError
