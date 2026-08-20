"""内容审核（模块⑧，PRD §8.2）。

**降级方向永远更保守**：机审失效或关闭时返回 PENDING（待审不公开），
绝不降级为直接 PUBLIC。这条不许「为了 demo 顺畅」放宽。
"""

from app.core.config import get_settings
from app.models.enums import LetterStatus

# 关键词表占位。实现时可外置为配置文件
BLOCKLIST: tuple[str, ...] = ()


async def moderate(content: str) -> LetterStatus:
    """返回信件应落入的状态。

    契约：
    1. FEATURE_MODERATION=false → 返回 PENDING（不公开，靠 seed 脚本/控制台放行）
    2. 命中关键词 → REJECTED
    3. LLM 分类判违规 → REJECTED
    4. LLM 调用失败/超时 → PENDING（**不是 PUBLIC**）
    5. 通过 → PUBLIC
    """
    settings = get_settings()
    if not settings.feature_moderation:
        return LetterStatus.PENDING
    raise NotImplementedError
