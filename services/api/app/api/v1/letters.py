"""写信与阅读（PRD 6.1）。

router 只做 HTTP ↔ service 转换，业务逻辑一律在 app/services/。
"""

from uuid import UUID

from fastapi import APIRouter, BackgroundTasks

from app.core.config import get_settings
from app.core.deps import CurrentUser, OptionalUser, Session
from app.models.enums import LetterStatus
from app.schemas.common import ReportRequest
from app.schemas.letter import LetterCreate, LetterOwned, LetterPublic
from app.services import letter_service, poem_service, resonance_service

router = APIRouter(tags=["letters"])


@router.post("/letters", response_model=LetterOwned, status_code=201)
async def create_letter(
    payload: LetterCreate, background_tasks: BackgroundTasks, session: Session, user_id: CurrentUser
) -> LetterOwned:
    """写一封信并投放。

    delivery_mode 必选：stay（锚定位置）或 drift（入随机漂流池）。
    提交后入审，默认 status=pending。
    审核通过的公开信在响应后由后台任务自动补写 AI 短诗
    （客户端已自带 poem 或 FEATURE_AI 关闭时跳过）。
    """
    letter = await letter_service.create_letter(session, payload, owner_user_id=user_id)
    # 后台写诗任务用独立连接读库，必须先把信提交落库
    # （get_session 的统一 commit 在响应发送后才执行，那时后台任务可能已在跑）
    await session.commit()
    if letter.status == LetterStatus.PUBLIC and payload.poem is None and get_settings().feature_ai:
        background_tasks.add_task(poem_service.generate_and_save_poem, letter.id)
    return LetterOwned.from_letter(letter, lat=payload.lat, lon=payload.lon)


@router.get("/letters/{letter_id}", response_model=LetterPublic)
async def read_letter(letter_id: UUID, session: Session, user_id: OptionalUser) -> LetterPublic:
    """读单封公开信（回信溯源用）。非 public 一律 404。

    纯读：不写 letter_reads、不动 read_count（开信上报走 POST /letters/{id}/read）。
    登录读者附带 me_resonated——点过共鸣的章常亮，重进未亮是反直觉的。
    """
    letter = await letter_service.get_public_letter(session, letter_id)
    me_resonated = (
        await resonance_service.has_resonated(session, letter_id, user_id) if user_id else False
    )
    return LetterPublic.from_letter(letter, me_resonated=me_resonated)


@router.post("/letters/{letter_id}/read", status_code=204)
async def mark_letter_read(letter_id: UUID, session: Session, user_id: CurrentUser) -> None:
    """开信上报（收信≠已读）。幂等：首开计一次 read_count，重复开不再计。"""
    await letter_service.mark_read(session, letter_id, user_id)


@router.post("/letters/{letter_id}/report", status_code=204)
async def report_letter(
    letter_id: UUID, payload: ReportRequest, session: Session, user_id: OptionalUser
) -> None:
    """举报（PRD §8.2）。入库待人工处理。匿名可举报（reporter 置空）。"""
    await letter_service.create_report(
        session, letter_id, reporter_user_id=user_id, reason=payload.reason, detail=payload.detail
    )
