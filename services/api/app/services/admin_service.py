"""管理端服务（PRD 6.14 / docs/ADMIN_CONSOLE.md）：AdminAccount 登录、
反馈查看/标注、信件审核与状态机、举报处置、统计概览、种子信件管理。

AdminAccount 与匿名用户体系完全隔离（PRD 6.14），登录失败一律 401，
不区分「账号不存在」与「密码错误」，避免账号枚举。
"""

from datetime import UTC, datetime, timedelta
from uuid import UUID

from geoalchemy2 import WKTElement
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import (
    InvalidTransition,
    LetterNotFound,
    NotFound,
    SeedLetterOnly,
    StayRequiresLocation,
    Unauthorized,
)
from app.core.security import create_admin_token, verify_password
from app.models.enums import (
    DeliveryMode,
    FeedbackCategory,
    FeedbackStatus,
    LetterStatus,
    ReportStatus,
)
from app.models.feedback import Feedback
from app.models.letter import Letter
from app.models.report import AdminAccount, Report
from app.models.user import User
from app.schemas.admin import (
    AdminLetterStatusUpdate,
    AdminReportUpdate,
    AdminSeedLetterUpdate,
    AdminStats,
)
from app.schemas.feedback import AdminFeedbackUpdateRequest
from app.schemas.letter import LetterCreate
from app.services import letter_service


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


# ---------- 信件审核与管理 ----------

# 管理端状态机（ADMIN_CONSOLE.md §3）：
# pending 审核裁决；public↔taken_down 下架/恢复；rejected 可赦免。
_ALLOWED_TRANSITIONS: dict[LetterStatus, frozenset[LetterStatus]] = {
    LetterStatus.PENDING: frozenset({LetterStatus.PUBLIC, LetterStatus.REJECTED}),
    LetterStatus.PUBLIC: frozenset({LetterStatus.TAKEN_DOWN}),
    LetterStatus.TAKEN_DOWN: frozenset({LetterStatus.PUBLIC}),
    LetterStatus.REJECTED: frozenset({LetterStatus.PUBLIC}),
}


async def list_letters(
    session: AsyncSession,
    *,
    status: LetterStatus | None = None,
    delivery_mode: DeliveryMode | None = None,
    owner: str | None = None,
    limit: int = 20,
) -> list[Letter]:
    """管理端信件列表（含非 public、含作者已「不再显示」的信），created_at DESC。

    owner=seed 只看 owner IS NULL（种子信），owner=user 只看有主信。
    """
    query = select(Letter).order_by(Letter.created_at.desc()).limit(limit)
    if status is not None:
        query = query.where(Letter.status == status)
    if delivery_mode is not None:
        query = query.where(Letter.delivery_mode == delivery_mode)
    if owner == "seed":
        query = query.where(Letter.owner_user_id.is_(None))
    elif owner == "user":
        query = query.where(Letter.owner_user_id.is_not(None))
    return list((await session.execute(query)).scalars().all())


async def get_letter(session: AsyncSession, letter_id: UUID) -> Letter:
    """管理端读信：全状态可见（读者侧的 public 守卫不适用于运营）。"""
    letter = await session.get(Letter, letter_id)
    if letter is None:
        raise LetterNotFound("信不存在")
    return letter


async def transition_letter_status(
    session: AsyncSession, letter_id: UUID, payload: AdminLetterStatusUpdate
) -> Letter:
    """审核/下架/恢复/赦免。表外流转一律 409 invalid_transition。

    note 仅随响应流转记录到举报备注的场景由前端处理；信件本体不存
    审核理由（v1 不建审计表，见 ADMIN_CONSOLE.md §6）。
    """
    letter = await get_letter(session, letter_id)
    allowed = _ALLOWED_TRANSITIONS.get(LetterStatus(letter.status), frozenset())
    if payload.status not in allowed:
        raise InvalidTransition(
            f"不允许从 {letter.status.value} 流转到 {payload.status.value}",
            detail={"from": letter.status.value, "to": payload.status.value},
        )
    letter.status = payload.status
    await session.commit()
    await session.refresh(letter)
    return letter


# ---------- 举报处置 ----------


async def list_reports(
    session: AsyncSession,
    *,
    status: ReportStatus | None = ReportStatus.OPEN,
    limit: int = 20,
) -> list[tuple[Report, Letter]]:
    """举报列表（JOIN 涉事信），created_at DESC。默认只看 open。"""
    query = (
        select(Report, Letter)
        .join(Letter, Report.letter_id == Letter.id)
        .order_by(Report.created_at.desc())
        .limit(limit)
    )
    if status is not None:
        query = query.where(Report.status == status)
    return [(row[0], row[1]) for row in (await session.execute(query)).all()]


async def update_report(
    session: AsyncSession, report_id: UUID, payload: AdminReportUpdate
) -> tuple[Report, Letter]:
    """举报处置：dismissed / actioned（下架信件由前端另调信件状态机）。

    置为已处理态回写 handled_at，回退 open 清空——与反馈同款口径。
    """
    report = await session.get(Report, report_id)
    if report is None:
        raise NotFound("举报不存在")

    if payload.status is not None:
        report.status = payload.status
        report.handled_at = datetime.now(UTC) if payload.status != ReportStatus.OPEN else None
    if payload.admin_note is not None:
        report.admin_note = payload.admin_note

    await session.commit()
    await session.refresh(report)
    letter = await session.get(Letter, report.letter_id)
    assert letter is not None  # FK 保证涉事信存在
    return report, letter


# ---------- 统计概览 ----------


async def stats(session: AsyncSession) -> AdminStats:
    """概览聚合。池口径同漂流/发掘筛选（status=public 按投放方式分列），
    不做 per-viewer 的已读/冷却过滤。"""
    now = datetime.now(UTC)

    by_status_rows = await session.execute(
        select(Letter.status, func.count()).group_by(Letter.status)
    )
    letters_by_status: dict[LetterStatus, int] = {row[0]: row[1] for row in by_status_rows.all()}

    users_total = await session.scalar(select(func.count()).select_from(User)) or 0

    async def _count_since(days: int) -> int:
        return (
            await session.scalar(
                select(func.count())
                .select_from(Letter)
                .where(Letter.created_at > now - timedelta(days=days))
            )
            or 0
        )

    async def _pool_count(mode: DeliveryMode) -> int:
        return (
            await session.scalar(
                select(func.count())
                .select_from(Letter)
                .where(Letter.status == LetterStatus.PUBLIC, Letter.delivery_mode == mode)
            )
            or 0
        )

    pending_letters = letters_by_status.get(LetterStatus.PENDING, 0)
    open_reports = (
        await session.scalar(
            select(func.count()).select_from(Report).where(Report.status == ReportStatus.OPEN)
        )
        or 0
    )
    open_feedbacks = (
        await session.scalar(
            select(func.count()).select_from(Feedback).where(Feedback.status == FeedbackStatus.OPEN)
        )
        or 0
    )

    return AdminStats(
        letters_by_status=letters_by_status,
        users_total=users_total,
        letters_7d=await _count_since(7),
        letters_30d=await _count_since(30),
        pool={
            "drift_available": await _pool_count(DeliveryMode.DRIFT),
            "stay_active": await _pool_count(DeliveryMode.STAY),
        },
        todo={
            "pending_letters": pending_letters,
            "open_reports": open_reports,
            "open_feedbacks": open_feedbacks,
        },
    )


# ---------- 种子信件管理 ----------


async def list_seed_letters(session: AsyncSession, *, limit: int = 50) -> list[Letter]:
    """种子信列表：owner IS NULL 的信（含被下架的），created_at DESC。"""
    return list(
        (
            await session.execute(
                select(Letter)
                .where(Letter.owner_user_id.is_(None))
                .order_by(Letter.created_at.desc())
                .limit(limit)
            )
        )
        .scalars()
        .all()
    )


async def create_seed_letter(session: AsyncSession, payload: LetterCreate) -> Letter:
    """新建种子信：复用写信校验，owner=NULL、直接 public 入池。

    运营自己就是审核者，跳过机审（letter_service.create_letter 的 status 直通）。
    """
    letter = await letter_service.create_letter(
        session, payload, owner_user_id=None, status=LetterStatus.PUBLIC
    )
    await session.commit()
    await session.refresh(letter)
    return letter


async def update_seed_letter(
    session: AsyncSession, letter_id: UUID, payload: AdminSeedLetterUpdate
) -> Letter:
    """编辑种子信：blocks/文案/落点/天气可改；theme 绑定红线不给改。

    仅限 owner IS NULL 的信——有主信走信件状态机，不可借种子信通道改内容。
    """
    letter = await get_letter(session, letter_id)
    if letter.owner_user_id is not None:
        raise SeedLetterOnly("只有无主种子信可以直接编辑内容")

    if payload.delivery_mode == DeliveryMode.STAY:
        if payload.lat is None or payload.lon is None:
            raise StayRequiresLocation("「留在这里」需要当前位置（lat/lon）")
        letter.location = WKTElement(
            f"POINT({payload.lon} {payload.lat})", srid=4326, extended=True
        )
    else:
        letter.location = None

    letter.blocks = [b.model_dump() for b in payload.blocks]
    letter.poem = payload.poem
    letter.signature = payload.signature
    letter.addressee = payload.addressee
    letter.music_ref = payload.music_ref.model_dump() if payload.music_ref is not None else None
    letter.tags = list(payload.tags)
    letter.delivery_mode = payload.delivery_mode
    letter.place_label = payload.place_label
    letter.weather = payload.weather.model_dump() if payload.weather is not None else None

    await session.commit()
    await session.refresh(letter)
    return letter
