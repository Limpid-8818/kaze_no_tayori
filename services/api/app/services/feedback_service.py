"""用户反馈的提交侧（管理侧在 admin_service）。"""

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.enums import FeedbackCategory
from app.models.feedback import Feedback


async def create_feedback(
    session: AsyncSession,
    user_id: UUID,
    category: FeedbackCategory,
    content: str,
    *,
    app_version: str | None = None,
    platform: str | None = None,
) -> Feedback:
    """落库一条反馈。本期用户侧无历史回显，提交即完成。"""
    feedback = Feedback(
        user_id=user_id,
        category=category,
        content=content,
        app_version=app_version,
        platform=platform,
    )
    session.add(feedback)
    await session.commit()
    await session.refresh(feedback)
    return feedback
