"""管理端（P1 起步）：AdminAccount 登录 + 反馈查看/标注。

与匿名用户体系完全隔离（PRD 6.14）：独立登录、独立 JWT（typ=admin）、
独立依赖 CurrentAdmin。apps/admin 前端尚未选型，本组接口即其数据源。
"""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Query

from app.core.deps import CurrentAdmin, Session
from app.models.enums import FeedbackCategory, FeedbackStatus
from app.schemas.common import Page
from app.schemas.feedback import (
    AdminFeedbackPublic,
    AdminFeedbackUpdateRequest,
    AdminLoginRequest,
    AdminTokenResponse,
)
from app.services import admin_service

router = APIRouter(prefix="/admin", tags=["admin"])


@router.post("/login", response_model=AdminTokenResponse)
async def admin_login(payload: AdminLoginRequest, session: Session) -> AdminTokenResponse:
    """用户名密码换 admin token（12h 短时效）。凭据错误一律 401。"""
    token = await admin_service.login(session, payload.username, payload.password)
    return AdminTokenResponse(access_token=token)


@router.get("/feedbacks", response_model=Page[AdminFeedbackPublic])
async def list_feedbacks(
    session: Session,
    admin_id: CurrentAdmin,
    status: FeedbackStatus | None = None,
    category: FeedbackCategory | None = None,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
) -> Page[AdminFeedbackPublic]:
    """反馈列表，created_at DESC，可按状态/类型筛选。"""
    rows = await admin_service.list_feedbacks(
        session, status=status, category=category, limit=limit
    )
    items = [
        AdminFeedbackPublic(
            id=f.id,
            user_id=f.user_id,
            category=f.category,
            content=f.content,
            app_version=f.app_version,
            platform=f.platform,
            status=f.status,
            admin_note=f.admin_note,
            handled_at=f.handled_at,
            created_at=f.created_at,
        )
        for f in rows
    ]
    return Page(items=items, next_cursor=None)


@router.patch("/feedbacks/{feedback_id}", response_model=AdminFeedbackPublic)
async def update_feedback(
    feedback_id: UUID,
    payload: AdminFeedbackUpdateRequest,
    session: Session,
    admin_id: CurrentAdmin,
) -> AdminFeedbackPublic:
    """标注反馈：改状态（open↔resolved，联动 handled_at）和/或写备注。"""
    f = await admin_service.update_feedback(session, feedback_id, payload)
    return AdminFeedbackPublic(
        id=f.id,
        user_id=f.user_id,
        category=f.category,
        content=f.content,
        app_version=f.app_version,
        platform=f.platform,
        status=f.status,
        admin_note=f.admin_note,
        handled_at=f.handled_at,
        created_at=f.created_at,
    )
