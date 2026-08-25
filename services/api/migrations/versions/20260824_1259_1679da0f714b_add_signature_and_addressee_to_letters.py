"""letters: add signature + addressee

Revision ID: 1679da0f714b
Revises: 3e7dce148beb
Create Date: 2026-08-24 12:59:41.999775+00:00

信尾署名（signature）与宛名（addressee）：写信人自填的信件内容物，
非作者/读者标识（匿名铁律不受影响，见 API_CONTRACT.md 偏差 #8）。
autogenerate 产物噪音极大（把无关表全部 drop/recreate 扫了进来），
本文件为人工重写的最小变更：两条 ADD COLUMN。
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "1679da0f714b"
down_revision: str | Sequence[str] | None = "3e7dce148beb"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# 表由 Alembic 连接的 search_path 定位，迁移不绑定任何开发者 schema。
_SCHEMA = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "letters",
        sa.Column("signature", sa.String(length=32), nullable=True),
        schema=_SCHEMA,
    )
    op.add_column(
        "letters",
        sa.Column("addressee", sa.String(length=32), nullable=True),
        schema=_SCHEMA,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("letters", "addressee", schema=_SCHEMA)
    op.drop_column("letters", "signature", schema=_SCHEMA)
