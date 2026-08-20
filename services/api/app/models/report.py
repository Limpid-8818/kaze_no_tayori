"""举报（PRD §8.2）。

PRD §9 未列此实体，但 8.2 要求提供举报入口，故按最小实现落表。
偏差已记录在 docs/API_CONTRACT.md §5。
"""

from uuid import UUID

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampCreated, UUIDPrimaryKey


class Report(Base, UUIDPrimaryKey, TimestampCreated):
    __tablename__ = "reports"

    letter_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("letters.id", ondelete="CASCADE"), nullable=False
    )
    # 举报者可匿名（未登录也能举报）
    reporter_user_id: Mapped[UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reason: Mapped[str] = mapped_column(String(32), nullable=False)
    detail: Mapped[str | None] = mapped_column(Text, nullable=True)


class AdminAccount(Base, UUIDPrimaryKey, TimestampCreated):
    """内容运营控制台账号（PRD 6.14，P1）。与匿名用户体系完全隔离。"""

    __tablename__ = "admin_accounts"

    username: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(16), nullable=False)
