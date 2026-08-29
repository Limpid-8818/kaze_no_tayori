"""add feedbacks table

Revision ID: 659578200280
Revises: b4e7a1c92d30
Create Date: 2026-08-29 02:24:54.900686+00:00

用户反馈（设置页入口提交）：问题/改进建议 + 管理端备注与 open→resolved
状态流转。autogenerate 产物因 search_path 误报全库 diff，已人工裁剪为
仅本表变更（两个 PG 原生枚举随 create_table 自动建型）。
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "659578200280"
down_revision: str | Sequence[str] | None = "b4e7a1c92d30"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# 表由 Alembic 连接的 search_path 定位，迁移不绑定任何开发者 schema。
_SCHEMA = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "feedbacks",
        sa.Column("user_id", sa.UUID(), nullable=True),
        sa.Column(
            "category", sa.Enum("bug", "suggestion", name="feedback_category"), nullable=False
        ),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("app_version", sa.String(length=32), nullable=True),
        sa.Column("platform", sa.String(length=16), nullable=True),
        sa.Column(
            "status",
            sa.Enum("open", "resolved", name="feedback_status"),
            server_default=sa.text("'open'"),
            nullable=False,
        ),
        sa.Column("admin_note", sa.Text(), nullable=True),
        sa.Column("handled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.UUID(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_feedbacks_user_id"), ondelete="SET NULL"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_feedbacks")),
        schema=_SCHEMA,
    )
    op.create_index(
        "ix_feedbacks_status_created",
        "feedbacks",
        ["status", "created_at"],
        unique=False,
        schema=_SCHEMA,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_feedbacks_status_created", table_name="feedbacks", schema=_SCHEMA)
    op.drop_table("feedbacks", schema=_SCHEMA)
    sa.Enum(name="feedback_status").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="feedback_category").drop(op.get_bind(), checkfirst=True)
