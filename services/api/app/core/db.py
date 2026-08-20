"""数据库引擎与会话。

共享云库靠 per-developer schema 隔离（见 docs/DEV_SETUP.md §5）：
连接时设 search_path 为 `<db_schema>,public`，PostGIS extension 装在 public 供各 schema 共用。
"""

from collections.abc import AsyncGenerator
from typing import Any

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.config import get_settings


def _connect_args(db_schema: str) -> dict[str, Any]:
    """asyncpg 通过 server_settings 设 search_path。"""
    return {"server_settings": {"search_path": f"{db_schema},public"}}


def create_engine() -> AsyncEngine:
    settings = get_settings()
    return create_async_engine(
        settings.database_url,
        echo=False,
        pool_pre_ping=True,
        connect_args=_connect_args(settings.db_schema),
    )


engine: AsyncEngine = create_engine()

SessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)


async def get_session() -> AsyncGenerator[AsyncSession]:
    """FastAPI 依赖：请求级会话。DB 访问一律经此获取，不要自建 session。"""
    async with SessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
