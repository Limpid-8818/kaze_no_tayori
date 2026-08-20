"""健康检查。

分两级是刻意的：`/health` 不碰数据库，这样在云库还没就绪时后端依然能起、
前端依然能联调（见 docs/DEV_SETUP.md）。

`/health/db` **不用 get_session 依赖**：依赖里建连接失败时异常在进入本函数之前
就抛出，try 块根本轮不到执行（会得到 500）。自检接口要自己管连接，才能把
「连不上」如实报成 503。
"""

from typing import Any

from fastapi import APIRouter
from sqlalchemy import text

from app.core.config import get_settings
from app.core.db import SessionLocal
from app.core.errors import ServiceUnavailable

router = APIRouter(tags=["health"])


@router.get("/health")
async def health() -> dict[str, str]:
    """进程存活。不连数据库。"""
    return {"status": "ok"}


@router.get("/health/db")
async def health_db() -> dict[str, Any]:
    """连库 + 确认 PostGIS 可用。

    连不上时返回 503（附排查指引），而不是 500——「云库还没配好」是本项目当前的
    预期状态，不是服务端 bug。
    """
    settings = get_settings()
    try:
        async with SessionLocal() as session:
            version = (await session.execute(text("SELECT PostGIS_version()"))).scalar_one()
            schema = (await session.execute(text("SELECT current_schema()"))).scalar_one()
    except Exception as exc:
        # 刻意宽catch：本接口的职责就是「如实报告任何连不上的原因」。
        # 连接期的 asyncpg 异常（如 ConnectionDoesNotExistError）既不是
        # SQLAlchemyError 也不是 OSError，窄 catch 会漏成 500。
        raise ServiceUnavailable(
            "数据库暂不可达，请检查 .env 里的 DATABASE_URL（见 docs/DEV_SETUP.md）",
            detail=type(exc).__name__,
        ) from exc

    return {
        "status": "ok",
        "postgis_version": version,
        "current_schema": schema,
        "configured_schema": settings.db_schema,
    }
