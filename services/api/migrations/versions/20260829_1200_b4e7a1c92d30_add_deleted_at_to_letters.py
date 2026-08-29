"""letters: add deleted_at

Revision ID: b4e7a1c92d30
Revises: 1679da0f714b
Create Date: 2026-08-29 12:00:00.000000+00:00

本人「不再显示」软删位（F6 后续）：/v1/me/letters 过滤掉已置位的行。
非硬删——回信链（parent_letter_id）、计数、通知全部保留，与「下架非硬删」
同一纪律。最小变更：一条 ADD COLUMN。
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b4e7a1c92d30"
down_revision: str | Sequence[str] | None = "1679da0f714b"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# 表由 Alembic 连接的 search_path 定位，迁移不绑定任何开发者 schema。
_SCHEMA = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "letters",
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        schema=_SCHEMA,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("letters", "deleted_at", schema=_SCHEMA)
