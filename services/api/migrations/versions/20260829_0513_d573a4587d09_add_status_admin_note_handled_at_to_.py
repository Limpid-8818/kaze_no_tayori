"""add status admin_note handled_at to reports

Revision ID: d573a4587d09
Revises: 659578200280
Create Date: 2026-08-29 05:13:47.760662+00:00

运营控制台举报处置位（docs/ADMIN_CONSOLE.md §3）。autogenerate 在
search_path 比对下产出了整库 drop/recreate 噪音，按惯例手写增量：
表由连接 search_path 定位，迁移不绑定开发者 schema（_SCHEMA = None）。
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "d573a4587d09"
down_revision: str | Sequence[str] | None = "659578200280"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_SCHEMA = None  # 表由 search_path 定位，迁移不绑定开发者 schema

_REPORT_STATUS = postgresql.ENUM(
    "open", "dismissed", "actioned", name="report_status", create_type=False
)


def upgrade() -> None:
    """Upgrade schema."""
    _REPORT_STATUS.create(op.get_bind(), checkfirst=True)
    op.add_column(
        "reports",
        sa.Column("status", _REPORT_STATUS, server_default=sa.text("'open'"), nullable=False),
        schema=_SCHEMA,
    )
    op.add_column("reports", sa.Column("admin_note", sa.Text(), nullable=True), schema=_SCHEMA)
    op.add_column(
        "reports",
        sa.Column("handled_at", sa.DateTime(timezone=True), nullable=True),
        schema=_SCHEMA,
    )
    op.create_index(
        "ix_reports_status_created",
        "reports",
        ["status", "created_at"],
        unique=False,
        schema=_SCHEMA,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_reports_status_created", table_name="reports", schema=_SCHEMA)
    op.drop_column("reports", "handled_at", schema=_SCHEMA)
    op.drop_column("reports", "admin_note", schema=_SCHEMA)
    op.drop_column("reports", "status", schema=_SCHEMA)
    _REPORT_STATUS.drop(op.get_bind(), checkfirst=True)
