"""blocks 图文交替流：content/images → blocks jsonb

Revision ID: blocks_flow
Revises: 602768f5b69d
Create Date: 2026-08-21 07:25:19.809984+00:00

"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "blocks_flow"
down_revision: str | Sequence[str] | None = "602768f5b69d"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    # 删掉旧的 content / images 列与其 CHECK 约束
    op.drop_check_constraint("ck_letters_content_max_len", table_name="letters")
    op.drop_check_constraint("ck_letters_images_max_3", table_name="letters")
    op.drop_column("letters", "content")
    op.drop_column("letters", "images")

    # 加 blocks 列（JSONB 数组，默认空数组）
    op.add_column(
        "letters",
        sa.Column(
            "blocks",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'[]'::jsonb"),
            nullable=False,
        ),
    )


def downgrade() -> None:
    """Downgrade schema."""
    # 删 blocks，恢复 content + images
    op.drop_column("letters", "blocks")

    op.add_column(
        "letters",
        sa.Column("content", sa.Text(), nullable=False),
    )
    op.add_column(
        "letters",
        sa.Column(
            "images",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'[]'::jsonb"),
            nullable=False,
        ),
    )
    op.create_check_constraint(
        "ck_letters_content_max_len",
        "letters",
        "char_length(content) <= 800",
    )
    op.create_check_constraint(
        "ck_letters_images_max_3",
        "letters",
        "jsonb_array_length(images) <= 3",
    )
