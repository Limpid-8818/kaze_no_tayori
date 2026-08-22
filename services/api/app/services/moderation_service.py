"""内容审核（模块⑧，PRD §8.2）。

**降级方向永远更保守**：机审失效或关闭时返回 PENDING（待审不公开），
绝不降级为直接 PUBLIC。这条不许「为了 demo 顺畅」放宽。
"""

import logging

from app.core.config import get_settings
from app.models.enums import LetterStatus

logger = logging.getLogger(__name__)

# 关键词表占位。开发期为空表（空表=全过，这是契约允许的 PUBLIC 路径）；
# LLM 分类接入（B7）后再收紧，或外置为配置文件。
BLOCKLIST: tuple[str, ...] = ()


def _text_from_blocks(blocks: list[dict]) -> str:
    """从图文交替流中提取纯正文（只拼 text 块）。"""
    return " ".join(b["text"] for b in blocks if b.get("type") == "text")


async def moderate(blocks: list[dict]) -> LetterStatus:
    """返回信件应落入的状态。

    契约：
    1. FEATURE_MODERATION=false → 返回 PENDING（不公开，靠 seed 脚本/控制台放行）
    2. 命中关键词 → REJECTED
    3. LLM 分类判违规 → REJECTED（B7 接入）
    4. LLM 调用失败/超时 → PENDING（**不是 PUBLIC**）
    5. 通过 → PUBLIC
    """
    settings = get_settings()
    if not settings.feature_moderation:
        return LetterStatus.PENDING

    try:
        text = _text_from_blocks(blocks)
        if any(word in text for word in BLOCKLIST):
            return LetterStatus.REJECTED
    except Exception:
        # 审核自身故障 → 待审不公开（红线 8）
        logger.exception("moderation failed, falling back to PENDING")
        return LetterStatus.PENDING
    return LetterStatus.PUBLIC
