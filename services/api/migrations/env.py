"""Alembic 环境。

三处关键配置（GeoAlchemy2 已知坑，缺一不可）：
- include_object              忽略 PostGIS 内部表（spatial_ref_sys 等）
- process_revision_directives 注入 create_geospatial_table 等空间操作
- render_item                 自动补 `from geoalchemy2 import Geography` 导入

不加这三项，autogenerate 会产出**重复的空间索引创建**并漏掉 geoalchemy2 导入。

连接串从仓库根 .env 的 DATABASE_URL_SYNC 读（psycopg 同步驱动），
不写在 alembic.ini 里，避免密钥进版本库。
"""

from logging.config import fileConfig

from alembic import context
from geoalchemy2 import alembic_helpers
from sqlalchemy import engine_from_config, pool, text

from app.core.config import get_settings

# 导入所有模型，让 target_metadata 完整（新增模型须在 app/models/__init__.py 登记）
from app.models import Base

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

settings = get_settings()
config.set_main_option("sqlalchemy.url", settings.database_url_sync)

target_metadata = Base.metadata

# 共享云库靠 per-developer schema 隔离，每个 schema 有自己的 alembic_version
VERSION_TABLE_SCHEMA = settings.db_schema if settings.db_schema != "public" else None


def _configure_kwargs() -> dict[str, object]:
    return {
        "target_metadata": target_metadata,
        "compare_type": True,
        "compare_server_default": True,
        "version_table_schema": VERSION_TABLE_SCHEMA,
        "include_schemas": True,
        # ↓ GeoAlchemy2 三件套，缺一不可
        "include_object": alembic_helpers.include_object,
        "process_revision_directives": alembic_helpers.writer,
        "render_item": alembic_helpers.render_item,
    }


def run_migrations_offline() -> None:
    context.configure(
        url=config.get_main_option("sqlalchemy.url"),
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        **_configure_kwargs(),  # type: ignore[arg-type]
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        # 确保自己的 schema 存在并置于 search_path 首位
        if VERSION_TABLE_SCHEMA:
            connection.execute(text(f'CREATE SCHEMA IF NOT EXISTS "{VERSION_TABLE_SCHEMA}"'))
            connection.execute(text(f'SET search_path TO "{VERSION_TABLE_SCHEMA}", public'))
            connection.commit()

        context.configure(connection=connection, **_configure_kwargs())  # type: ignore[arg-type]
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
