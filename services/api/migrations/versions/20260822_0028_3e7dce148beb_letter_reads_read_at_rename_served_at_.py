"""letter_reads: read_at rename served_at + opened_at

Revision ID: 3e7dce148beb
Revises: theme_skin
Create Date: 2026-08-22 00:28:15.865657+00:00

收信 ≠ 已读：read_at(读时间) 拆成 served_at(送达时间) + opened_at(开信时间)。
autogenerate 产物噪音极大（把无关表全部 drop/recreate 扫了进来），
本文件为人工重写的最小变更。
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "3e7dce148beb"
down_revision: str | Sequence[str] | None = "theme_skin"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_SCHEMA = "dev_limpid"


def upgrade() -> None:
    """Upgrade schema."""
    op.alter_column(
        "letter_reads",
        "read_at",
        new_column_name="served_at",
        existing_type=sa.DateTime(timezone=True),
        existing_nullable=False,
        existing_server_default=sa.text("now()"),
        schema=_SCHEMA,
    )
    op.add_column(
        "letter_reads",
        sa.Column("opened_at", sa.DateTime(timezone=True), nullable=True),
        schema=_SCHEMA,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("letter_reads", "opened_at", schema=_SCHEMA)
    op.alter_column(
        "letter_reads",
        "served_at",
        new_column_name="read_at",
        existing_type=sa.DateTime(timezone=True),
        existing_nullable=False,
        existing_server_default=sa.text("now()"),
        schema=_SCHEMA,
    )
