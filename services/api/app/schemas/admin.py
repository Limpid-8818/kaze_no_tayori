"""管理端 schema（PRD 6.14 / docs/ADMIN_CONSOLE.md）。

与对外响应的隔离点：AdminLetterDetail 是**唯一**允许携带 `owner_user_id`
的信件形状（管理端区分种子信/处置举报用，用途受 ADMIN_CONSOLE.md §1 约束）。
读者侧响应仍只能用 LetterPublic / LetterOwned（test_anonymity 持续守卫）。
"""

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models.enums import DeliveryMode, LetterStatus, ReportStatus
from app.schemas.letter import (
    LetterCounts,
    LetterPublic,
    MusicRef,
    Weather,
    _BlocksMixin,
    _decode_point,
)


def _preview_text(blocks: list[dict[str, Any]], max_len: int = 60) -> str | None:
    """列表预览：第一个文本块截断。没有文本块（纯照片流）返回 None。"""
    for block in blocks:
        if isinstance(block, dict) and block.get("type") == "text":
            text = str(block.get("text") or "").strip()
            if text:
                return text[:max_len]
    return None


class AdminLetterSummary(BaseModel):
    """管理端信件列表项（含非 public）。刻意不含 blocks 全量与 owner。"""

    id: str
    status: LetterStatus
    delivery_mode: DeliveryMode
    place_label: str | None = None
    lat: float | None = None
    lon: float | None = None
    preview: str | None = None
    counts: LetterCounts
    created_at: str

    @classmethod
    def from_letter(cls, letter: Any) -> "AdminLetterSummary":
        lat, lon = _decode_point(letter.location)
        return cls(
            id=str(letter.id),
            status=letter.status,
            delivery_mode=letter.delivery_mode,
            place_label=letter.place_label,
            lat=lat,
            lon=lon,
            preview=_preview_text(letter.blocks),
            counts=LetterCounts(
                read=letter.read_count,
                resonance=letter.resonance_count,
                voice=letter.voice_count,
                reply=letter.reply_count,
                saved=letter.saved_count,
            ),
            created_at=letter.created_at.isoformat(),
        )


class AdminLetterDetail(LetterPublic):
    """管理端信件详情 = 读者可见形状 + status + owner_user_id。

    owner_user_id 是匿名设备 UUID，仅管理端可见（区分种子信/处置举报），
    对访客「不暴露作者」的口径不变（ADMIN_CONSOLE.md §1）。
    """

    status: LetterStatus
    owner_user_id: UUID | None = None

    @classmethod
    def detail_from(cls, letter: Any) -> "AdminLetterDetail":
        """不叫 from_letter：签名与父类 LetterPublic.from_letter 不同，避免 override 冲突。"""
        data = LetterPublic.from_letter(letter).model_dump()
        data.update(status=letter.status, owner_user_id=letter.owner_user_id)
        return cls(**data)


class AdminLetterStatusUpdate(BaseModel):
    """管理端信件状态流转。表内合法流转见 admin_service._ALLOWED_TRANSITIONS。"""

    status: LetterStatus
    note: str | None = Field(default=None, max_length=500)


class AdminReportLetterBrief(BaseModel):
    """举报列表内嵌的涉事信摘要（区别于独立 AdminLetterSummary：少坐标计数）。"""

    id: str
    status: LetterStatus
    delivery_mode: DeliveryMode
    place_label: str | None = None
    preview: str | None = None

    @classmethod
    def from_letter(cls, letter: Any) -> "AdminReportLetterBrief":
        return cls(
            id=str(letter.id),
            status=letter.status,
            delivery_mode=letter.delivery_mode,
            place_label=letter.place_label,
            preview=_preview_text(letter.blocks),
        )


class AdminReportPublic(BaseModel):
    id: UUID
    letter: AdminReportLetterBrief
    reporter_user_id: UUID | None = None
    reason: str
    detail: str | None = None
    status: ReportStatus
    admin_note: str | None = None
    handled_at: datetime | None = None
    created_at: datetime


class AdminReportUpdate(BaseModel):
    """举报处置：改状态和/或写备注。处置=下架信件由前端另行调信件状态机。"""

    status: ReportStatus | None = None
    admin_note: str | None = Field(default=None, max_length=500)

    @model_validator(mode="after")
    def _require_any(self) -> "AdminReportUpdate":
        if self.status is None and self.admin_note is None:
            raise ValueError("status 与 admin_note 至少提供一项")
        return self


class AdminPoolHealth(BaseModel):
    """池健康度：口径同漂流/发掘筛选（status=public 按投放方式分列）。

    drift_available 是全局池量（不含个体已读/冷却过滤——那是 per-viewer 的）。
    """

    drift_available: int
    stay_active: int


class AdminTodoCounts(BaseModel):
    """待办角标三源。"""

    pending_letters: int
    open_reports: int
    open_feedbacks: int


class AdminStats(BaseModel):
    """概览聚合（GET /v1/admin/stats）。"""

    letters_by_status: dict[LetterStatus, int]
    users_total: int
    letters_7d: int
    letters_30d: int
    pool: AdminPoolHealth
    todo: AdminTodoCounts


# ---------- 种子信件管理 ----------


class AdminSeedLetterUpdate(_BlocksMixin):
    """种子信编辑：blocks/文案/落点/天气可改；theme 绑定红线不给改。

    delivery_mode=stay 时 lat/lon 必填（校验在 service 层，与写信同口径）。
    """

    poem: str | None = None
    signature: str | None = Field(default=None, max_length=32)
    addressee: str | None = Field(default=None, max_length=32)
    music_ref: MusicRef | None = None
    tags: list[str] = Field(default_factory=list, max_length=3)
    delivery_mode: DeliveryMode
    lat: float | None = Field(default=None, ge=-90, le=90)
    lon: float | None = Field(default=None, ge=-180, le=180)
    place_label: str | None = Field(default=None, max_length=128)
    weather: Weather | None = None
    model_config = ConfigDict(extra="forbid")
