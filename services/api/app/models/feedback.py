"""用户反馈：问题与改进建议（设置页入口提交，管理端查看/备注/状态流转）。

用户提交侧只落库不回显（本期无「我的反馈」历史）；管理侧走 /v1/admin/*。
"""

from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, Enum, ForeignKey, Index, String, Text, text
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampCreated, UUIDPrimaryKey
from app.models.enums import FeedbackCategory, FeedbackStatus


class Feedback(Base, UUIDPrimaryKey, TimestampCreated):
    __tablename__ = "feedbacks"

    # 提交者设备身份；设备退场（users 行删除）后反馈仍保留
    user_id: Mapped[UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    category: Mapped[FeedbackCategory] = mapped_column(
        Enum(
            FeedbackCategory,
            name="feedback_category",
            native_enum=True,
            values_callable=lambda cls: [e.value for e in cls],
        ),
        nullable=False,
    )
    content: Mapped[str] = mapped_column(Text, nullable=False)
    # 提交时客户端自动附带的环境上下文，帮助定位问题
    app_version: Mapped[str | None] = mapped_column(String(32), nullable=True)
    platform: Mapped[str | None] = mapped_column(String(16), nullable=True)
    status: Mapped[FeedbackStatus] = mapped_column(
        Enum(
            FeedbackStatus,
            name="feedback_status",
            native_enum=True,
            values_callable=lambda cls: [e.value for e in cls],
        ),
        nullable=False,
        server_default=text("'open'"),
    )
    admin_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    handled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (Index("ix_feedbacks_status_created", "status", "created_at"),)
