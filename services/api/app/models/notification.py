"""回信告知（PRD 6.5）。

**这不是私信**：原作者只是「获知」他写的那封信收到了一封回信，
而那封回信是独立作品、面向所有陌生人。原作者不是收件人，也无法回复。

可达性边界：仅当原信 owner_user_id 非空时才产生通知；纯过客所写的信收到回信时
静默跳过，该回信照样公开，由后来者经 parent 溯源发现。
"""

from uuid import UUID

from sqlalchemy import Boolean, ForeignKey, Index, text
from sqlalchemy import Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampCreated, UUIDPrimaryKey
from app.models.enums import NotificationType


class Notification(Base, UUIDPrimaryKey, TimestampCreated):
    __tablename__ = "notifications"

    user_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    type: Mapped[NotificationType] = mapped_column(
        SAEnum(NotificationType, name="notification_type", native_enum=True), nullable=False
    )
    # 那封回信
    letter_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("letters.id", ondelete="CASCADE"), nullable=False
    )
    # 被回的原信（「你于 {地点} 写的那封信」）
    parent_letter_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("letters.id", ondelete="CASCADE"), nullable=False
    )
    is_read: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))

    __table_args__ = (Index("ix_notifications_inbox", "user_id", "is_read"),)
