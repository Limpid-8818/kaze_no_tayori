"""SQLAlchemy 2.0 声明式基类。

约定：
- 所有表 id 用 UUID，服务端默认 gen_random_uuid()（PG 13+ 内置，无需 pgcrypto）
- 时间一律 TIMESTAMPTZ
- 表结构只描述数据，不写业务方法（业务逻辑在 app/services/）
"""

from datetime import datetime
from typing import Any
from uuid import UUID

from sqlalchemy import DateTime, MetaData, func, text
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

from app.core.config import get_settings

# 统一命名约定，让 Alembic autogenerate 产出稳定的约束名
NAMING_CONVENTION: dict[str, Any] = {
    "ix": "ix_%(table_name)s_%(column_0_N_name)s",
    "uq": "uq_%(table_name)s_%(column_0_N_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s",
    "pk": "pk_%(table_name)s",
}


class Base(DeclarativeBase):
    # schema 由 .env 的 DB_SCHEMA 决定：共享云库靠 per-developer schema 隔离
    metadata = MetaData(
        naming_convention=NAMING_CONVENTION,
        schema=get_settings().db_schema if get_settings().db_schema != "public" else None,
    )


class UUIDPrimaryKey:
    """UUID 主键 mixin。"""

    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )


class TimestampCreated:
    """创建时间 mixin。"""

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
