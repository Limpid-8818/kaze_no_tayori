"""信服务（模块①）：信件存取、状态机、计数自增。"""

from typing import Any, cast
from uuid import UUID

from geoalchemy2 import Geometry, WKTElement
from sqlalchemy import CursorResult, func, select, update
from sqlalchemy import cast as sql_cast
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import LetterNotFound, LetterNotRetired, StayRequiresLocation
from app.models.enums import LetterStatus
from app.models.letter import Letter
from app.models.letter_read import LetterRead
from app.models.report import Report
from app.schemas.letter import LetterCreate
from app.services import moderation_service


async def create_letter(
    session: AsyncSession,
    payload: LetterCreate,
    owner_user_id: UUID | None,
    parent_letter_id: UUID | None = None,
    *,
    status: LetterStatus | None = None,
    created_at: Any | None = None,
) -> Letter:
    """建信。

    契约：
    - delivery_mode=stay 时 lat/lon 必填，写入 location（geography POINT 4326）
    - 走审核（moderation_service）决定 status；审核不可用时停在 pending
    - status 直通（运营控制台种子信）时跳过审核，运营自己就是审核者
    - created_at 直通（种子信回溯落款）时覆盖 server_default 的当下
    - theme 写入后永久绑定，后续不得批量迁移
    - parent_letter_id 仅由 service 预置（回信场景），schema 不接受客户端直传
    """
    location: WKTElement | None = None
    if payload.delivery_mode == "stay":
        if payload.lat is None or payload.lon is None:
            raise StayRequiresLocation("「留在这里」需要当前位置（lat/lon）")
        # extended=True → EWKB，与 geography 列直接兼容
        location = WKTElement(f"POINT({payload.lon} {payload.lat})", srid=4326, extended=True)

    letter = Letter(
        blocks=[b.model_dump() for b in payload.blocks],
        poem=payload.poem,
        signature=payload.signature,
        addressee=payload.addressee,
        theme_id=payload.theme_id,
        theme_skin=payload.theme_skin.model_dump(by_alias=True) if payload.theme_skin else None,
        music_ref=payload.music_ref.model_dump() if payload.music_ref else None,
        tags=list(payload.tags),
        location=location,
        place_label=payload.place_label,
        # Pydantic 模型不能直接进 JSONB（json.dumps 不认），与上面两个嵌套体一致先 dump
        weather=payload.weather.model_dump() if payload.weather else None,
        delivery_mode=payload.delivery_mode,
        status=status
        or await moderation_service.moderate([b.model_dump() for b in payload.blocks]),
        owner_user_id=owner_user_id,
        parent_letter_id=parent_letter_id,
    )
    # None 不能显式赋给 server_default 列（会 INSERT NULL），只在提供时覆盖
    if created_at is not None:
        letter.created_at = created_at
    session.add(letter)
    await session.flush()
    # created_at / id 是 server_default，refresh 取回
    await session.refresh(letter)
    return letter


async def get_public_letter(session: AsyncSession, letter_id: UUID) -> Letter:
    """读一封公开信。非 public 抛 NotFound（不泄漏「存在但未公开」）。"""
    result = await session.execute(
        select(Letter).where(Letter.id == letter_id, Letter.status == LetterStatus.PUBLIC)
    )
    letter = result.scalar_one_or_none()
    if letter is None:
        raise LetterNotFound("信不存在或尚未漂到公开水域")
    return letter


async def mark_read(session: AsyncSession, letter_id: UUID, user_id: UUID) -> None:
    """开信标记（POST /v1/letters/{id}/read）。read_count 的唯一自增点。

    收信 ≠ 已读：drift 抽取只写 served_at；此处才写 opened_at 并计数。
    幂等：首开（drift 路径已 served / discover 路径无记录）计数一次，
    重复开信不再计。非 public 抛 LetterNotFound。
    """
    await get_public_letter(session, letter_id)

    # discover 路径没有 served 行：直接插入已开信行 → rowcount=1 计数
    # （Result 运行时是 CursorResult，mypy 看不到 rowcount，cast 收口）
    inserted = cast(
        CursorResult[Any],
        await session.execute(
            pg_insert(LetterRead)
            .values(letter_id=letter_id, user_id=user_id, opened_at=func.now())
            .on_conflict_do_nothing()
        ),
    )
    if inserted.rowcount == 1:
        await _bump_read_count(session, letter_id)
        return

    # drift 路径：行已存在（served 未开）→ NULL→now 迁移成功才计数
    transitioned = cast(
        CursorResult[Any],
        await session.execute(
            update(LetterRead)
            .where(
                LetterRead.letter_id == letter_id,
                LetterRead.user_id == user_id,
                LetterRead.opened_at.is_(None),
            )
            .values(opened_at=func.now())
        ),
    )
    if transitioned.rowcount == 1:
        await _bump_read_count(session, letter_id)


async def _bump_read_count(session: AsyncSession, letter_id: UUID) -> None:
    await session.execute(
        update(Letter)
        .where(Letter.id == letter_id)
        .values(read_count=Letter.read_count + 1)
        .execution_options(synchronize_session=False)
    )


async def create_report(
    session: AsyncSession,
    letter_id: UUID,
    reporter_user_id: UUID | None,
    reason: str,
    detail: str | None,
) -> None:
    """举报入库（PRD §8.2）。reporter 可空 = 匿名举报。

    先走 public 守卫：对非 public 信举报同样 404，不泄漏存在性。
    """
    await get_public_letter(session, letter_id)
    session.add(
        Report(
            letter_id=letter_id,
            reporter_user_id=reporter_user_id,
            reason=reason,
            detail=detail,
        )
    )
    await session.flush()


async def list_owned_letters(
    session: AsyncSession, owner_user_id: UUID, limit: int
) -> list[tuple[Letter, float | None, float | None]]:
    """我写下的信，含 pending。按 created_at DESC。返回 (letter, lon, lat)。

    坐标从 geography 列反解：ST_X / ST_Y 仅接受 geometry，
    因此显式 CAST(location AS geometry)（PostGIS 3.6 实测）。
    drift 信 location 为 NULL → 坐标返回 None。
    已「不再显示」（deleted_at 软删位）的行不返回。
    """
    result = await session.execute(
        select(
            Letter,
            func.st_x(sql_cast(Letter.location, Geometry)).label("lon"),
            func.st_y(sql_cast(Letter.location, Geometry)).label("lat"),
        )
        .where(Letter.owner_user_id == owner_user_id, Letter.deleted_at.is_(None))
        .order_by(Letter.created_at.desc())
        .limit(limit)
    )
    return [(row[0], row.lon, row.lat) for row in result.all()]


async def take_down(session: AsyncSession, letter_id: UUID, owner_user_id: UUID) -> None:
    """下架自己的信 → status=taken_down。非硬删，保留回信链完整性。"""
    result = cast(
        CursorResult[Any],
        await session.execute(
            update(Letter)
            .where(Letter.id == letter_id, Letter.owner_user_id == owner_user_id)
            .values(status=LetterStatus.TAKEN_DOWN)
            .execution_options(synchronize_session=False)
        ),
    )
    if result.rowcount == 0:
        raise LetterNotFound("信不存在或你没有权限操作此信")


async def hide(session: AsyncSession, letter_id: UUID, owner_user_id: UUID) -> None:
    """「不再显示」→ deleted_at 软删位，/v1/me/letters 不再返回。

    处置决定而非视图筛选：仅已退场（taken_down / rejected）的信可隐藏，
    公开中/审核中须先下架。非硬删，回信链与计数保留。
    """
    letter = (
        await session.execute(
            select(Letter).where(Letter.id == letter_id, Letter.owner_user_id == owner_user_id)
        )
    ).scalar_one_or_none()
    if letter is None or letter.deleted_at is not None:
        raise LetterNotFound("信不存在或你没有权限操作此信")
    if letter.status not in (LetterStatus.TAKEN_DOWN, LetterStatus.REJECTED):
        raise LetterNotRetired("公开中或审核中的信要先下架，才能从列表收起")
    letter.deleted_at = func.now()
