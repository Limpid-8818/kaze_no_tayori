"""信件 schema。

**这是匿名铁律的执行点（CLAUDE.md 红线 1）。**

`LetterPublic` 刻意不含 `owner_user_id` 或任何作者标识，也不含精确坐标——
一切对外的信件响应都必须用它。想「顺便带上作者」就得改这个类，而
`tests/test_anonymity.py` 会立刻变红。
"""

from typing import Annotated, Literal

from pydantic import BaseModel, Field, model_validator

from app.models.enums import DeliveryMode, LetterStatus

# ---------- 图文交替流（PRD 6.1 · blocks）----------

_VALID_MOODS = {"none", "overexposed", "backlit", "motion"}


class TextBlock(BaseModel):
    """一段手写正文。"""

    type: Literal["text"] = "text"
    text: str = Field(min_length=1, max_length=800)


class PhotoBlock(BaseModel):
    """一张照片（带可选 mood 与手记）。"""

    type: Literal["photo"] = "photo"
    ref: str = Field(min_length=1, max_length=512, description="图片引用（URL 或资产标识）")
    mood: str = Field(
        default="none", description=f"拍摄瞬间 mood：{'|'.join(sorted(_VALID_MOODS))}"
    )
    note: str | None = Field(default=None, max_length=200, description="照片手记（hwNote）")

    @model_validator(mode="after")
    def _check_mood(self) -> "PhotoBlock":
        if self.mood not in _VALID_MOODS:
            raise ValueError(f"mood 必须是 {sorted(_VALID_MOODS)} 之一，got: {self.mood!r}")
        return self


# discriminated union — Pydantic v2 按 `type` 字段分发
LetterBlock = Annotated[TextBlock | PhotoBlock, Field(discriminator="type")]


def _count_photos(blocks: list) -> int:
    return sum(1 for b in blocks if isinstance(b, PhotoBlock))


class _BlocksMixin(BaseModel):
    """共用的 blocks 字段 + 流校验。"""

    blocks: list[LetterBlock] = Field(min_length=1, max_length=20)

    @model_validator(mode="after")
    def _check_flow(self) -> "_BlocksMixin":
        photos = _count_photos(self.blocks)
        if photos > 3:
            raise ValueError("一封信最多夹三张照片")
        return self


# ---------- 引用式音乐（PRD 6.7）----------


class MusicRef(BaseModel):
    """引用式音乐：只有三个字符串。

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


# ---------- 请求 / 响应 ----------


class LetterCreate(_BlocksMixin):
    """写信（PRD 6.1）。"""

    poem: str | None = None
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
    model_config = {"extra": "forbid"}


class LetterPublic(_BlocksMixin):
    """对外信件响应——**唯一允许返回给读者的信件形状**。

    刻意缺席的字段：
    - owner_user_id / 任何作者标识（匿名铁律）
    - lat / lon 精确坐标（只给 place_label，避免反查作者活动位置，PRD §8.1）
    - status（读者只会看到 public 的信）
    """

    id: str  # UUID serialized as string
    poem: str | None = None
    theme: str
    music_ref: MusicRef | None = None
    place_label: str | None = None
    weather: Weather | None = None
    tags: list[str] = Field(default_factory=list)
    delivery_mode: DeliveryMode
    parent_letter_id: str | None = None
    counts: LetterCounts
    created_at: str  # ISO 8601 datetime serialized as string


class LetterOwned(LetterPublic):
    """本人视角，仅 /v1/me/* 路径返回。

    比 LetterPublic 多出状态与自己的落点坐标。**仍不含 owner_user_id**——
    自己不需要看自己的 id。
    """

    status: LetterStatus
    lat: float | None = None
    lon: float | None = None
