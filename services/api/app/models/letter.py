"""漂流信（系统第一公民）。

红线提醒（见根 CLAUDE.md §2）：
- `blocks` 图文交替流：正文段与照片块的有序流，禁止回到 flat content+images
- `theme` 永久绑定单信，禁止批量 UPDATE
- `music_ref` 只有 {album, song, lyrics}，不许加 url / audio 字段
- `expire_at` 恒为 NULL，不实现过期清理
- 计数只有 5 个，不许新增 like / hot / score 语义的列
"""

from datetime import datetime
from typing import Any
from uuid import UUID

from geoalchemy2 import Geography
from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    text,
)
from sqlalchemy import (
    Enum as SAEnum,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampCreated, UUIDPrimaryKey
from app.models.enums import DeliveryMode, LetterStatus


class Letter(Base, UUIDPrimaryKey, TimestampCreated):
    __tablename__ = "letters"

    # ---------- 内容（图文交替流）----------
    # blocks = [{"type":"text","text":"…"}, {"type":"photo","ref":"url",
    #   "mood":"overexposed","note":"…"}]
    # 空流校验在 service 层；照片上限 3 也在 service 层做叙事化校验
    blocks: Mapped[list[dict[str, Any]]] = mapped_column(
        JSONB, nullable=False, server_default=text("'[]'::jsonb")
    )
    # AI 短诗，≤4 行
    poem: Mapped[str | None] = mapped_column(Text, nullable=True)
    # ---------- 皮肤搭配（PRD 6.9）----------
    # theme_id 指向 themes 表的基础主题（如 "natsu"），theme_skin 是槽位搭配的 jsonb
    # 两者一旦写入永久绑定单信，禁止批量 UPDATE（CLAUDE.md 红线 6）
    theme_id: Mapped[str] = mapped_column(
        String(32), nullable=False, server_default=text("'natsu'")
    )
    theme_skin: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)
    # 引用式音乐：{album, song, lyrics}。不生成、不上传、不外链
    music_ref: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)
    tags: Mapped[list[str]] = mapped_column(
        JSONB, nullable=False, server_default=text("'[]'::jsonb")
    )

    # ---------- 落点（此情此景，非此人是谁）----------
    # Geography 而非 Geometry：ST_DWithin 直接以米为单位，省掉投影换算
    location: Mapped[Any | None] = mapped_column(
        Geography(geometry_type="POINT", srid=4326), nullable=True
    )
    place_label: Mapped[str | None] = mapped_column(String(128), nullable=True)
    weather: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)

    # ---------- 投放与状态 ----------
    # values_callable：PG 枚举值取 StrEnum 的 value（小写），与 server_default、
    # Pydantic 序列化、裸 SQL 查询的直觉一致。不传则默认用成员名（大写）。
    delivery_mode: Mapped[DeliveryMode] = mapped_column(
        SAEnum(
            DeliveryMode,
            name="delivery_mode",
            native_enum=True,
            values_callable=lambda cls: [e.value for e in cls],
        ),
        nullable=False,
    )
    status: Mapped[LetterStatus] = mapped_column(
        SAEnum(
            LetterStatus,
            name="letter_status",
            native_enum=True,
            values_callable=lambda e: [i.value for i in e],
        ),
        nullable=False,
        server_default=text("'pending'"),
    )

    # ---------- 关系 ----------
    # 可空：纯过客（未绑定 device/账号）所写的信，对应 PRD 6.5 可达性边界
    owner_user_id: Mapped[UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    # 回信溯源。回信是独立信件，不是私信，不许建 conversation/thread 表
    parent_letter_id: Mapped[UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("letters.id", ondelete="SET NULL"), nullable=True
    )

    # 预留字段，默认 NULL=永驻。初赛不启用过期
    expire_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # ---------- 叙事计数（替代空间轨迹，不跨信排行）----------
    read_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    resonance_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    voice_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    reply_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    saved_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))

    __table_args__ = (
        # blocks 非空在服务层校验（需要叙事化错误信息），此处只保底
        CheckConstraint("jsonb_typeof(blocks) = 'array'", name="blocks_is_array"),
        # 漂流池筛选
        Index("ix_letters_pool", "status", "delivery_mode"),
        # 回信溯源
        Index("ix_letters_parent", "parent_letter_id"),
        # 我的信
        Index("ix_letters_owner", "owner_user_id", text("created_at DESC")),
        # 注意：location 的 GiST 索引由 GeoAlchemy2 在建表时自动创建
        # （Geography 列默认 spatial_index=True），**不要在此重复声明**，
        # 否则 Alembic autogenerate 会产出重复的 create_index。
    )
