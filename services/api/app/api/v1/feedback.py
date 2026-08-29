"""用户反馈提交（设置页入口）。

POST /v1/feedback —— 已登录设备提交一条问题/建议。本期无「我的反馈」
历史，提交侧只落库；查看与标注走管理端 /v1/admin/feedbacks。
"""

from fastapi import APIRouter

from app.core.deps import CurrentUser, Session
from app.schemas.feedback import FeedbackCreateRequest, FeedbackPublic
from app.services import feedback_service

router = APIRouter(prefix="/feedback", tags=["feedback"])


@router.post("", response_model=FeedbackPublic, status_code=201)
async def submit_feedback(
    payload: FeedbackCreateRequest, session: Session, user_id: CurrentUser
) -> FeedbackPublic:
    feedback = await feedback_service.create_feedback(
        session,
        user_id,
        payload.category,
        payload.content,
        app_version=payload.app_version,
        platform=payload.platform,
    )
    return FeedbackPublic(
        id=feedback.id,
        category=feedback.category,
        status=feedback.status,
        created_at=feedback.created_at,
    )
