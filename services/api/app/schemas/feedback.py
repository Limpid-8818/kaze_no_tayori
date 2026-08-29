"""用户反馈 schema：用户提交侧与管理端查看/标注侧分离。"""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, model_validator

from app.models.enums import FeedbackCategory, FeedbackStatus

FEEDBACK_MAX_CHARS = 2000


# ---------- 用户提交 ----------
class FeedbackCreateRequest(BaseModel):
    """设置页反馈表单：类型单选 + 正文。版本/平台由客户端自动附带，服务端仅截断落库。"""

    category: FeedbackCategory
    content: str = Field(min_length=1, max_length=FEEDBACK_MAX_CHARS)
    app_version: str | None = Field(default=None, max_length=32)
    platform: str | None = Field(default=None, max_length=16)

    @model_validator(mode="after")
    def _strip_content(self) -> "FeedbackCreateRequest":
        self.content = self.content.strip()
        if not self.content:
            raise ValueError("反馈内容不能为空")
        return self


class FeedbackPublic(BaseModel):
    """提交确认。用户侧最小回显，不含管理字段。"""

    id: UUID
    category: FeedbackCategory
    status: FeedbackStatus
    created_at: datetime


# ---------- 管理端 ----------
class AdminFeedbackPublic(BaseModel):
    """管理端视图：含提交环境上下文与处理标注。"""

    id: UUID
    user_id: UUID | None
    category: FeedbackCategory
    content: str
    app_version: str | None
    platform: str | None
    status: FeedbackStatus
    admin_note: str | None
    handled_at: datetime | None
    created_at: datetime


class AdminFeedbackUpdateRequest(BaseModel):
    """管理端标注：改状态和/或写备注，至少动一项。"""

    status: FeedbackStatus | None = None
    admin_note: str | None = Field(default=None, max_length=2000)

    @model_validator(mode="after")
    def _at_least_one(self) -> "AdminFeedbackUpdateRequest":
        if self.status is None and self.admin_note is None:
            raise ValueError("至少提供 status 或 admin_note 之一")
        if self.admin_note is not None:
            self.admin_note = self.admin_note.strip() or None
        return self


class AdminLoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=64)
    password: str = Field(min_length=1, max_length=128)


class AdminTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
