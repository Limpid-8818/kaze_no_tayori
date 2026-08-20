"""信服务（模块①）：信件存取、状态机、计数自增。

脚手架阶段：只定签名与契约，不实现逻辑。
"""

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.letter import Letter
from app.schemas.letter import LetterCreate


async def create_letter(
    session: AsyncSession, payload: LetterCreate, owner_user_id: UUID | None
) -> Letter:
    """建信。

    契约：
    - delivery_mode=stay 时 lat/lon 必填，写入 location（geography POINT 4326）
    - 走审核（moderation_service）决定 status；审核不可用时停在 pending
    - theme 写入后永久绑定，后续不得批量迁移
    """
    raise NotImplementedError


async def get_public_letter(session: AsyncSession, letter_id: UUID) -> Letter:
    """读一封公开信。非 public 抛 NotFound（不泄漏「存在但未公开」）。"""
    raise NotImplementedError


async def list_owned_letters(
    session: AsyncSession, owner_user_id: UUID, limit: int
) -> list[Letter]:
    """我写下的信，含 pending。按 created_at DESC。"""
    raise NotImplementedError


async def take_down(session: AsyncSession, letter_id: UUID, owner_user_id: UUID) -> None:
    """下架自己的信 → status=taken_down。非硬删，保留回信链完整性。"""
    raise NotImplementedError
