"""内容审核（模块⑧，PRD §8.2）。

**降级方向永远更保守**：机审失效或关闭时返回 PENDING（待审不公开），
绝不降级为直接 PUBLIC。这条不许「为了 demo 顺畅」放宽。
"""

import logging

from app.core.config import get_settings
from app.models.enums import LetterStatus
from app.services.llm_client import chat_completion

logger = logging.getLogger(__name__)

# 关键词表占位。开发期为空表（空表=全过，这是契约允许的 PUBLIC 路径）；
# 需要时再收紧，或外置为配置文件。
BLOCKLIST: tuple[str, ...] = ()

MODERATION_SYSTEM_PROMPT = (
    "你是一个内容审核分类器。用户给你一封将要公开的信的正文，"
    "判断它是否包含：违法犯罪、色情低俗、暴力血腥、人身攻击辱骂、"
    "垃圾广告、隐私泄露（如他人手机号/身份证号）或其他不适公开展示的内容。"
    '只输出一个词：合规输出 "APPROVED"，违规输出 "REJECTED"，不要任何其他文字。'
)


def _text_from_blocks(blocks: list[dict]) -> str:
    """从图文交替流中提取纯正文（只拼 text 块）。"""
    return " ".join(b["text"] for b in blocks if b.get("type") == "text")


async def _moderate_by_llm(text: str) -> LetterStatus | None:
    """LLM 分类。返回 REJECTED/PUBLIC；失败或输出不可解析时返回 None（落 PENDING）。"""
    result = await chat_completion(
        [
            {"role": "system", "content": MODERATION_SYSTEM_PROMPT},
            {"role": "user", "content": text},
        ],
        max_tokens=1024,  # 推理型模型先产 reasoning_content，预算太小会导致 content 为空
        temperature=0.0,
    )
    if result is None:
        return None
    verdict = result.strip().upper()
    if "REJECT" in verdict:
        return LetterStatus.REJECTED
    if "APPROVE" in verdict:
        return LetterStatus.PUBLIC
    return None


async def moderate(blocks: list[dict]) -> LetterStatus:
    """返回信件应落入的状态。

    契约：
    1. FEATURE_MODERATION=false → 返回 PENDING（不公开，靠 seed 脚本/控制台放行）
    2. 命中关键词 → REJECTED
    3. LLM 分类判违规 → REJECTED
    4. LLM 调用失败/超时/输出不可解析 → PENDING（**不是 PUBLIC**）
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

    verdict = await _moderate_by_llm(text)
    if verdict is None:
        logger.warning("LLM moderation unavailable or unparseable, falling back to PENDING")
        return LetterStatus.PENDING
    return verdict
