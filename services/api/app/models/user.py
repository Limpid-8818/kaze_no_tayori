"""用户（PRD 6.13）。

账户存在是为了支撑跨设备、「我的信」、抄本、回信通知；**发布层永远匿名**。
数据最小化（PRD §8.1）：不存任何画像字段。
"""

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampCreated, UUIDPrimaryKey


class User(Base, UUIDPrimaryKey, TimestampCreated):
    __tablename__ = "users"

    # 设备绑定：客户端生成的 UUIDv4，无密码即可获得身份
    device_id: Mapped[str] = mapped_column(String(64), unique=True, nullable=False, index=True)

    # P1：可选升级为账号以跨设备
    email: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
