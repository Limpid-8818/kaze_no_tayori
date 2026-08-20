"""静态目录：思绪标签与主题皮肤。

两者都是预置数据，由 scripts/seed_letters.py 灌入。
主题皮肤只是装饰层（PRD 6.9）：`theme` 字段解耦，新增主题仅加皮肤包，
且一旦被信件选定即永久绑定，不做季节归档/自动迁移。
"""

from typing import Any

from sqlalchemy import Boolean, String, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class ThoughtTag(Base):
    """预置思绪标签（PRD 6.8，P1）。用于收信轻度匹配与聚合。"""

    __tablename__ = "thought_tags"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    name: Mapped[str] = mapped_column(String(32), nullable=False)
    color: Mapped[str] = mapped_column(String(9), nullable=False)


class Theme(Base):
    """主题皮肤（PRD 6.9）。P0 只有「夏」natsu。"""

    __tablename__ = "themes"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    name: Mapped[str] = mapped_column(String(32), nullable=False)
    assets: Mapped[dict[str, Any]] = mapped_column(
        JSONB, nullable=False, server_default=text("'{}'::jsonb")
    )
    is_default: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
