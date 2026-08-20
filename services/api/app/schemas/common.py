"""通用 schema：认证、分页、其余交互。"""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.enums import NotificationType


# ---------- 分页 ----------
class Page[T](BaseModel):
    items: list[T]
    next_cursor: str | None = None


# ---------- 认证（PRD 6.13）----------
class DeviceAuthRequest(BaseModel):
    """设备绑定：无密码、无强制注册。"""

    device_id: str = Field(min_length=8, max_length=64)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: UUID


# ---------- AI（PRD 6.2，可关）----------
class PolishRequest(BaseModel):
    content: str = Field(min_length=1, max_length=800)


class PolishResponse(BaseModel):
    """AI 是桥不是枪手：润色保留原意，用户可选采纳。"""

    polished: str


class PoemResponse(BaseModel):
    poem: str = Field(description="从正文提取意象生成，≤4 行")


# ---------- 共鸣（PRD 6.6）----------
class ResonanceRequest(BaseModel):
    note: str | None = Field(default=None, max_length=30, description="可选匿名短句")


class ResonanceResponse(BaseModel):
    """只回计数。**不返回共鸣者**，也不存在共鸣者列表接口。"""

    resonance_count: int


# ---------- 抄本（PRD 6.10）----------
class ScripbookAddRequest(BaseModel):
    letter_id: UUID
    note: str | None = None


# ---------- 通知（PRD 6.5）----------
class NotificationPublic(BaseModel):
    """回信告知。原作者不是回信的收件人，这只是「获知」。"""

    id: UUID
    type: NotificationType
    letter_id: UUID
    parent_letter_id: UUID
    parent_place_label: str | None = None
    is_read: bool
    created_at: datetime


# ---------- 举报（PRD §8.2）----------
class ReportRequest(BaseModel):
    reason: str = Field(max_length=32)
    detail: str | None = None


# ---------- 静态目录 ----------
class ThemePublic(BaseModel):
    id: str
    name: str
    assets: dict[str, object] = Field(default_factory=dict)
    is_default: bool


class TagPublic(BaseModel):
    id: str
    name: str
    color: str


# ---------- 图片上传 ----------
class UploadResponse(BaseModel):
    url: str
