"""信件 schema。

**这是匿名铁律的执行点（CLAUDE.md 红线 1）。**

`LetterPublic` 刻意不含 `owner_user_id` 或任何作者标识——一切对外的
信件响应都必须用它。想「顺便带上作者」就得改这个类，而
`tests/test_anonymity.py` 会立刻变红。落点坐标（lat/lon）按 2026-08
裁决对外下发；location 原始列仍不出现。
"""

from typing import Annotated, Any, Literal

from pydantic import BaseModel, Field, model_validator

from app.models.enums import DeliveryMode, LetterStatus


def _decode_point(location: Any) -> tuple[float | None, float | None]:
    """Geography/Geometry 列 → (lat, lon)。

    反解失败（None、未加载、非点几何）一律 (None, None)，与地理模块
    同款降级纪律：坐标缺席不阻断信件响应。
    """
    if location is None:
        return None, None
    try:
        from geoalchemy2.shape import to_shape

        point = to_shape(location)
        # to_shape 静态返回 BaseGeometry，运行时是 Point（x/y 只在 Point 上）
        return float(point.y), float(point.x)  # type: ignore[attr-defined]
    except Exception:
        return None, None


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
        default="none",
        description="拍摄瞬间 mood：none|overexposed|backlit|motion",
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


# ---------- 皮肤搭配（PRD 6.9 · theme_skin）----------


class LetterSkin(BaseModel):
    """信件皮肤搭配——各槽只存资产 ID 字符串。

    空槽 = 不携带该层皮肤，渲染层用默认值。**全空 = 全默认**（不携带皮肤的信）。
    一旦写入永久绑定，不做季节归档/自动迁移（CLAUDE.md 红线 6）。
    """

    stamp: str | None = Field(default=None, description="邮票资产 ID")
    postmark_emblem: str | None = Field(
        default=None, alias="postmarkEmblem", description="邮戳中心图案资产 ID"
    )
    decor: list[str] = Field(default_factory=list, description="装饰资产 ID 列表（可多枚）")
    postcard: str | None = Field(default=None, description="明信片底图资产 ID")

    model_config = {"populate_by_name": True}


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
    # 信尾署名（可空 = 不署名）。内容物，非作者标识
    signature: str | None = Field(default=None, max_length=32)
    # 宛名（封筒封面收信人，可空）。内容物，非读者标识
    addressee: str | None = Field(default=None, max_length=32)
    # 基础主题 ID（如 "natsu"），指向 themes 表
    theme_id: str = Field(default="natsu", max_length=32)
    # 皮肤搭配（可选，不传则全默认）
    theme_skin: LetterSkin | None = None
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
    - status（读者只会看到 public 的信）

    落点坐标（lat/lon）按 2026-08 裁决对外下发：落点坐标是公开的创作
    元素（写信时作者主动选定的位置），读者用它计算与自己的直线距离；
    location 原始列与作者标识仍然缺席。drift 信 / 无落点信为 null。
    """

    id: str  # UUID serialized as string
    poem: str | None = None
    signature: str | None = None
    addressee: str | None = None
    theme_id: str
    theme_skin: LetterSkin | None = None
    music_ref: MusicRef | None = None
    place_label: str | None = None
    weather: Weather | None = None
    tags: list[str] = Field(default_factory=list)
    delivery_mode: DeliveryMode
    parent_letter_id: str | None = None
    counts: LetterCounts

    # 落点坐标（stay 信）；drift 信或反解失败为 null
    lat: float | None = None
    lon: float | None = None

    # 当前读者是否已共鸣过（一次性，详情接口按登录用户下发）。
    # 列表接口不计算、恒为 False——读信页总是重新拉详情，以详情为准。
    me_resonated: bool = False
    created_at: str  # ISO 8601 datetime serialized as string

    @classmethod
    def from_letter(cls, letter: Any, me_resonated: bool = False) -> "LetterPublic":
        """ORM Letter → 对外形状。counts/created_at 是派生字段，不能 from_attributes。"""
        lat, lon = _decode_point(letter.location)
        return cls(
            id=str(letter.id),
            blocks=letter.blocks,
            poem=letter.poem,
            signature=letter.signature,
            addressee=letter.addressee,
            theme_id=letter.theme_id,
            theme_skin=letter.theme_skin,
            music_ref=letter.music_ref,
            place_label=letter.place_label,
            weather=letter.weather,
            tags=letter.tags,
            delivery_mode=letter.delivery_mode,
            parent_letter_id=str(letter.parent_letter_id) if letter.parent_letter_id else None,
            counts=LetterCounts(
                read=letter.read_count,
                resonance=letter.resonance_count,
                voice=letter.voice_count,
                reply=letter.reply_count,
                saved=letter.saved_count,
            ),
            lat=lat,
            lon=lon,
            me_resonated=me_resonated,
            created_at=letter.created_at.isoformat(),
        )


class LetterOwned(LetterPublic):
    """本人视角，仅 /v1/me/* 路径返回。

    比 LetterPublic 多出 status。坐标继承自 LetterPublic 的落点反解；
    **仍不含 owner_user_id**——自己不需要看自己的 id。
    """

    status: LetterStatus

    @classmethod
    def from_letter(
        cls, letter: Any, lat: float | None = None, lon: float | None = None
    ) -> "LetterOwned":
        """lat/lon 由调用方（建信时来自 payload）传入，非 None 时覆盖落点反解。"""
        data = LetterPublic.from_letter(letter).model_dump()
        data.update(status=letter.status)
        if lat is not None:
            data["lat"] = lat
        if lon is not None:
            data["lon"] = lon
        return cls(**data)
