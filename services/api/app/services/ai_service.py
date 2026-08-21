"""AI 润色与短诗（模块⑥，PRD 6.2，可降级）。

**AI 是桥不是枪手**：润色必须保留原意，用户可选采纳；整体关闭不影响主流程。
FEATURE_AI=false 时抛 FeatureDisabled(503)，前端据此降级为纯手动写信——
这是预期的降级路径，不是错误。
"""

from app.core.config import get_settings
from app.core.errors import FeatureDisabled

# 提示词占位。实现时保持「保留原意、不替代表达」的约束写进 system prompt
POLISH_SYSTEM_PROMPT = ""
POEM_SYSTEM_PROMPT = ""


def _require_enabled() -> None:
    if not get_settings().feature_ai:
        raise FeatureDisabled("AI 辅助当前不可用，可以直接手写这封信")


def _text_from_blocks(blocks: list[dict]) -> str:
    """从图文交替流中提取纯正文（只拼 text 块）。"""
    return " ".join(b["text"] for b in blocks if b.get("type") == "text")


async def polish(blocks: list[dict]) -> str:
    """润色正文，保留原意。

    契约：调用失败/超时时同样抛 FeatureDisabled，让前端降级，**不要抛 500**。
    """
    _require_enabled()
    _text_from_blocks(blocks)
    raise NotImplementedError


async def compose_poem(blocks: list[dict]) -> str:
    """从正文提取意象生成 ≤4 行短诗。失败时同上降级。"""
    _require_enabled()
    _text_from_blocks(blocks)
    raise NotImplementedError
