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

# 统一命名约定，让 Alembic autogenerate 产出稳定的约束名
NAMING_CONVENTION: dict[str, Any] = {
    "ix": "ix_%(table_name)s_%(column_0_N_name)s",
    "uq": "uq_%(table_name)s_%(column_0_N_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s",
    "pk": "pk_%(table_name)s",
}


class Base(DeclarativeBase):
    # 生产路径 schema 保持 None：表名不带 schema 前缀，
    # 由引擎连接时的 search_path（app/core/db.py）解析到 per-developer schema。
    # 测试用 set_schema() 动态覆盖（见 tests/conftest.py）。
    metadata = MetaData(
        naming_convention=NAMING_CONVENTION,
        schema=None,
    )


def set_schema(schema: str | None) -> None:
    """动态设置 Base.metadata.schema。

    测试环境在 import 之后才决定 schema（先 monkeypatch settings，
    再调用此函数同步 metadata），避免 module-level get_settings() 过早固化。
    """
    Base.metadata.schema = schema
    # 同时更新所有已注册 Table 的 schema，否则 create_all() 会使用
    # Table 自身的 schema（可能是 None），而不是 MetaData.schema
    for table in Base.metadata.tables.values():
        table.schema = schema


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
