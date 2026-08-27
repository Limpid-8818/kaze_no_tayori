"""寄出后自动写诗（后台任务）。

**AI 是桥不是枪手**：自动写诗是增强不是主流程——任何失败只降级为
「信件无短诗」，绝不影响寄出结果。客户端已自带 poem 的信不覆盖。
"""

import logging
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.enums import LetterStatus
from app.models.letter import Letter
from app.services import ai_service

logger = logging.getLogger(__name__)


async def write_poem_for_letter(session: AsyncSession, letter_id: UUID) -> bool:
    """为公开信补写 AI 短诗（不 commit，由调用方决定事务边界）。

    守卫：
    - 仅 public 信写诗（pending/rejected/taken_down 不浪费 LLM 配额）
    - poem 已有值则跳过（尊重用户经 /ai/poem 获取的内容）
    - 回写带 poem IS NULL 条件，防与并发路径互踩

    返回是否写入了短诗。
    """
    letter = (
        await session.execute(select(Letter).where(Letter.id == letter_id))
    ).scalar_one_or_none()
    if letter is None or letter.status != LetterStatus.PUBLIC or letter.poem:
        return False

    poem = await ai_service.compose_poem(list(letter.blocks))
    await session.execute(
        update(Letter)
        .where(Letter.id == letter_id, Letter.poem.is_(None))
        .values(poem=poem)
        .execution_options(synchronize_session=False)
    )
    return True


async def generate_and_save_poem(letter_id: UUID) -> None:
    """BackgroundTasks 入口：自建会话完成写诗回写。

    请求级 session 此时已关闭，函数内懒导入 SessionLocal（保持可被测试替换）。
    异常只记日志——后台任务不允许把异常抛回事件循环，
    留无诗的信就是预期降级形态。
    """
    try:
        from app.core.db import SessionLocal

        async with SessionLocal() as session:
            await write_poem_for_letter(session, letter_id)
            await session.commit()
    except Exception:
        logger.warning("自动写诗失败，letter_id=%s", letter_id, exc_info=True)
