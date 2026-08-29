"""管理端服务：AdminAccount 登录与反馈的查看/标注。

AdminAccount 与匿名用户体系完全隔离（PRD 6.14），登录失败一律 401，
不区分「账号不存在」与「密码错误」，避免账号枚举。
"""

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFound, Unauthorized
from app.core.security import create_admin_token, verify_password
from app.models.enums import FeedbackCategory, FeedbackStatus
from app.models.feedback import Feedback
from app.models.report import AdminAccount
from app.schemas.feedback import AdminFeedbackUpdateRequest


async def login(session: AsyncSession, username: str, password: str) -> str:
    """校验用户名密码，返回 admin JWT。凭据错误一律 Unauthorized。"""
    admin = (
        await session.execute(select(AdminAccount).where(AdminAccount.username == username))
    ).scalar_one_or_none()
    if admin is None or not verify_password(password, admin.password_hash):
        raise Unauthorized("用户名或密码错误")
    return create_admin_token(admin.id)


async def list_feedbacks(
    session: AsyncSession,
    *,
    status: FeedbackStatus | None = None,
    category: FeedbackCategory | None = None,
    limit: int = 20,
) -> list[Feedback]:
    """反馈列表，created_at DESC。分页口径与 /v1/me/* 一致（limit 截断）。"""
    query = select(Feedback).order_by(Feedback.created_at.desc()).limit(limit)
    if status is not None:
        query = query.where(Feedback.status == status)
    if category is not None:
        query = query.where(Feedback.category == category)
    return list((await session.execute(query)).scalars().all())


async def update_feedback(
    session: AsyncSession, feedback_id: UUID, payload: AdminFeedbackUpdateRequest
) -> Feedback:
    """管理端标注：改状态和/或备注。置 resolved 时回写 handled_at，回退则清空。"""
    feedback = await session.get(Feedback, feedback_id)
    if feedback is None:
        raise NotFound("反馈不存在")

    if payload.status is not None:
        feedback.status = payload.status
        feedback.handled_at = (
            datetime.now(UTC) if payload.status == FeedbackStatus.RESOLVED else None
        )
    if payload.admin_note is not None:
        feedback.admin_note = payload.admin_note

    await session.commit()
    await session.refresh(feedback)
    return feedback
