"""信件 schema。

**这是匿名铁律的执行点（CLAUDE.md 红线 1）。**

`LetterPublic` 刻意不含 `owner_user_id` 或任何作者标识，也不含精确坐标——
一切对外的信件响应都必须用它。想「顺便带上作者」就得改这个类，而
tests/test_anonymity.py 会立刻变红。
"""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import DeliveryMode, LetterStatus


class MusicRef(BaseModel):
    """引用式音乐（PRD 6.7）：只有三个字符串。

    不生成音频、不上传音频、不贴外部链接——**不许新增 url / audio 字段**。
    """

    album: str = Field(max_length=128)
    song: str = Field(max_length=128)
    lyrics: str = Field(max_length=200, description="一句歌词")


class Weather(BaseModel):
    """落点天气，「此情此景」的锚点之一。"""

    text: str = Field(max_length=32)
    temp_c: float | None = None
    icon: str | None = Field(default=None, max_length=32)


class LetterCounts(BaseModel):
    """叙事计数（PRD §7.4）：替代空间轨迹，且不跨信排行。

    共鸣呈现为「已被 N 个陌生人接住」，不是点赞数。
    """

    read: int = 0
    resonance: int = 0
    voice: int = 0
    reply: int = 0
    saved: int = 0


class LetterCreate(BaseModel):
    """写信（PRD 6.1）。"""

    content: str = Field(min_length=1, max_length=800)
    poem: str | None = None
    images: list[str] = Field(default_factory=list, max_length=3)
    theme: str = Field(default="natsu", max_length=32)
    music_ref: MusicRef | None = None
    tags: list[str] = Field(default_factory=list, max_length=3)

    # 必选投递方式：留在这里 / 投递出去，两者都是一等公民
    delivery_mode: DeliveryMode

    # delivery_mode=stay 时必填（校验在 service 层，便于给出叙事化错误信息）
    lat: float | None = Field(default=None, ge=-90, le=90)
    lon: float | None = Field(default=None, ge=-180, le=180)
    place_label: str | None = Field(default=None, max_length=128)
    weather: Weather | None = None

    # 回信时由 service 预置，不接受客户端直传
    model_config = ConfigDict(extra="forbid")


class LetterPublic(BaseModel):
    """对外信件响应——**唯一允许返回给读者的信件形状**。

    刻意缺席的字段：
    - owner_user_id / 任何作者标识（匿名铁律）
    - lat / lon 精确坐标（只给 place_label，避免反查作者活动位置，PRD §8.1）
    - status（读者只会看到 public 的信）
    """

    id: UUID
    content: str
    poem: str | None = None
    images: list[str] = Field(default_factory=list)
    theme: str
    music_ref: MusicRef | None = None
    place_label: str | None = None
    weather: Weather | None = None
    tags: list[str] = Field(default_factory=list)
    delivery_mode: DeliveryMode
    parent_letter_id: UUID | None = None
    counts: LetterCounts
    created_at: datetime


class LetterOwned(LetterPublic):
    """本人视角，仅 /v1/me/* 路径返回。

    比 LetterPublic 多出状态与自己的落点坐标。**仍不含 owner_user_id**——
    自己不需要看自己的 id。
    """

    status: LetterStatus
    lat: float | None = None
    lon: float | None = None
