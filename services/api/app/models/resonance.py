"""共鸣记录（PRD 6.6）。

✦ 共鸣**不是点赞**：只计数、不展示谁、不提供共鸣者列表接口。
信件对外只呈现「已被 N 个陌生人接住」。
"""

from uuid import UUID

from sqlalchemy import ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampCreated, UUIDPrimaryKey


class ResonanceLog(Base, UUIDPrimaryKey, TimestampCreated):
    __tablename__ = "resonance_logs"

    letter_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("letters.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    # 可选短句「我也曾有过这样的时刻」，≤30 字，匿名存储（P1）
    note: Mapped[str | None] = mapped_column(String(30), nullable=True)

    __table_args__ = (
        # 同一人对同一封信只能共鸣一次
        UniqueConstraint("letter_id", "user_id", name="uq_resonance_once"),
    )
