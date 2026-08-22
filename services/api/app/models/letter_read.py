"""送达与开信记录。

**PRD §9 未列的推导实体**（偏差已记录在 docs/API_CONTRACT.md §5）：
PRD 6.3 要求随机漂流抽取「非自己发、未读过」的信，而 `read_count` 只是聚合值，
无法判断某个体是否读过，因此必须有这张表。

一行两层语义（收信 ≠ 已读）：
- `served_at`：drift 抽取送达时间。冷却期内送达过的信不重发（被丢弃的未开封
  信在冷却后回到池里，未来仍可漂来）。
- `opened_at`：真正开信时间，NULL = 收到未开封。`read_count` 只在 NULL→有值
  的迁移时自增一次（POST /v1/letters/{id}/read，幂等）。

它只服务于「不重复给同一个人同一封信」与 discover 的已开封过滤，
不用于任何画像或推荐。
"""

from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class LetterRead(Base):
    __tablename__ = "letter_reads"

    letter_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("letters.id", ondelete="CASCADE"),
        primary_key=True,
    )
    user_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    served_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    opened_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
