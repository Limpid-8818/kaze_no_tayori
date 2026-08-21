"""theme_skin 槽位搭配：theme → theme_id + theme_skin jsonb

Revision ID: theme_skin
Revises: blocks_flow
Create Date: 2026-08-21 07:44:08.638111+00:00

"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "theme_skin"
down_revision: str | Sequence[str] | None = "blocks_flow"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    # 重命名 theme → theme_id（类型不变，仍是 varchar(32) NOT NULL DEFAULT 'natsu'）
    op.alter_column("letters", "theme", new_column_name="theme_id", existing_nullable=False)
    # 加 theme_skin 列（JSONB，可空——不携带皮肤的信为 null）
    op.add_column(
        "letters",
        sa.Column(
            "theme_skin",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("letters", "theme_skin")
    op.alter_column("letters", "theme_id", new_column_name="theme", existing_nullable=False)
