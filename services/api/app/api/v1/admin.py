"""管理端（PRD 6.14 / docs/ADMIN_CONSOLE.md）。

与匿名用户体系完全隔离（PRD 6.14）：独立登录、独立 JWT（typ=admin）、
独立依赖 CurrentAdmin。读端点 CurrentAdmin（viewer 可用），
写端点 AdminWriter（role=admin，viewer 403 admin_forbidden）。
"""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Query

from app.core.deps import AdminWriter, CurrentAdmin, Session
from app.models.enums import (
    DeliveryMode,
    FeedbackCategory,
    FeedbackStatus,
    LetterStatus,
    ReportStatus,
)
from app.schemas.admin import (
    AdminLetterDetail,
    AdminLetterStatusUpdate,
    AdminLetterSummary,
    AdminReportLetterBrief,
    AdminReportPublic,
    AdminReportUpdate,
    AdminSeedLetterCreate,
    AdminSeedLetterUpdate,
    AdminStats,
)
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


@router.get("/stats", response_model=AdminStats)
async def get_stats(session: Session, admin_id: CurrentAdmin) -> AdminStats:
    """概览聚合：状态分布 / 用户数 / 7·30 日新增 / 池健康 / 待办角标。"""
    return await admin_service.stats(session)


# ---------- 信件审核与管理 ----------


@router.get("/letters", response_model=Page[AdminLetterSummary])
async def list_letters(
    session: Session,
    admin_id: CurrentAdmin,
    status: LetterStatus | None = None,
    delivery_mode: DeliveryMode | None = None,
    owner: Annotated[str | None, Query(pattern="^(seed|user)$")] = None,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
) -> Page[AdminLetterSummary]:
    """信件列表（含非 public），created_at DESC。owner=seed|user 区分种子信/有主信。"""
    rows = await admin_service.list_letters(
        session, status=status, delivery_mode=delivery_mode, owner=owner, limit=limit
    )
    return Page(items=[AdminLetterSummary.from_letter(letter) for letter in rows], next_cursor=None)


@router.get("/letters/{letter_id}", response_model=AdminLetterDetail)
async def get_letter(
    letter_id: UUID, session: Session, admin_id: CurrentAdmin
) -> AdminLetterDetail:
    """信件详情（全状态可见 + owner_user_id，仅管理端可见）。"""
    letter = await admin_service.get_letter(session, letter_id)
    return AdminLetterDetail.detail_from(letter)


@router.patch("/letters/{letter_id}/status", response_model=AdminLetterDetail)
async def transition_letter_status(
    letter_id: UUID,
    payload: AdminLetterStatusUpdate,
    session: Session,
    writer: AdminWriter,
) -> AdminLetterDetail:
    """审核/下架/恢复/赦免。状态机见 admin_service._ALLOWED_TRANSITIONS，表外 409。"""
    letter = await admin_service.transition_letter_status(session, letter_id, payload)
    return AdminLetterDetail.detail_from(letter)


# ---------- 举报处理 ----------


@router.get("/reports", response_model=Page[AdminReportPublic])
async def list_reports(
    session: Session,
    admin_id: CurrentAdmin,
    status: ReportStatus | None = None,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
) -> Page[AdminReportPublic]:
    """举报列表（JOIN 涉事信摘要），created_at DESC。

    status 缺省 = 全部（含已处理）；「默认只看待处理」由前端显式传 open。
    """
    rows = await admin_service.list_reports(session, status=status, limit=limit)
    items = [
        AdminReportPublic(
            id=report.id,
            letter=AdminReportLetterBrief.from_letter(letter),
            reporter_user_id=report.reporter_user_id,
            reason=report.reason,
            detail=report.detail,
            status=report.status,
            admin_note=report.admin_note,
            handled_at=report.handled_at,
            created_at=report.created_at,
        )
        for report, letter in rows
    ]
    return Page(items=items, next_cursor=None)


@router.patch("/reports/{report_id}", response_model=AdminReportPublic)
async def update_report(
    report_id: UUID,
    payload: AdminReportUpdate,
    session: Session,
    writer: AdminWriter,
) -> AdminReportPublic:
    """举报处置：dismissed / actioned（置已处理回写 handled_at，回退 open 清空）。"""
    report, letter = await admin_service.update_report(session, report_id, payload)
    return AdminReportPublic(
        id=report.id,
        letter=AdminReportLetterBrief.from_letter(letter),
        reporter_user_id=report.reporter_user_id,
        reason=report.reason,
        detail=report.detail,
        status=report.status,
        admin_note=report.admin_note,
        handled_at=report.handled_at,
        created_at=report.created_at,
    )


# ---------- 反馈管理 ----------


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
    writer: AdminWriter,
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


# ---------- 种子信件管理 ----------


@router.get("/seed-letters", response_model=Page[AdminLetterSummary])
async def list_seed_letters(
    session: Session,
    admin_id: CurrentAdmin,
    limit: Annotated[int, Query(ge=1, le=50)] = 50,
) -> Page[AdminLetterSummary]:
    """种子信列表（owner IS NULL，含被下架的），created_at DESC。"""
    rows = await admin_service.list_seed_letters(session, limit=limit)
    return Page(items=[AdminLetterSummary.from_letter(letter) for letter in rows], next_cursor=None)


@router.post("/seed-letters", response_model=AdminLetterDetail, status_code=201)
async def create_seed_letter(
    payload: AdminSeedLetterCreate, session: Session, writer: AdminWriter
) -> AdminLetterDetail:
    """新建种子信：复用写信校验，owner=NULL、直接 public 入池（跳过机审）；
    created_at 可回溯落款（须为过去，否则 400 seed_created_at_in_future）。"""
    letter = await admin_service.create_seed_letter(session, payload)
    return AdminLetterDetail.detail_from(letter)


@router.patch("/seed-letters/{letter_id}", response_model=AdminLetterDetail)
async def update_seed_letter(
    letter_id: UUID,
    payload: AdminSeedLetterUpdate,
    session: Session,
    writer: AdminWriter,
) -> AdminLetterDetail:
    """编辑种子信：blocks/文案/落点/天气可改；theme 绑定不给改；仅限无主信。"""
    letter = await admin_service.update_seed_letter(session, letter_id, payload)
    return AdminLetterDetail.detail_from(letter)
