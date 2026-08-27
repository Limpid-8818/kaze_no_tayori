"""AI 润色与短诗（模块⑥，PRD 6.2，可降级）。

**AI 是桥不是枪手**：润色必须保留原意，用户可选采纳；整体关闭不影响主流程。
FEATURE_AI=false 时抛 FeatureDisabled(503)，前端据此降级为纯手动写信——
这是预期的降级路径，不是错误。
"""

from app.core.config import get_settings
from app.core.errors import FeatureDisabled
from app.services.llm_client import chat_completion

# 「保留原意、不替代表达」的约束必须写进 system prompt
POLISH_SYSTEM_PROMPT = (
    "你是一封信件的润色助手。用户给你一段将要寄出的信的正文，"
    "你只做轻微的润色：修正错别字和标点、理顺不通顺的句子、让语气更自然。"
    "必须保留原意和作者的个人语气，不增加新内容、不删减信息、不改写风格。"
    "只输出润色后的正文本身，不要任何解释或前后缀。"
)

# 默认俳句：三行短诗，从正文提取意象，须含季语
POEM_SYSTEM_PROMPT = (
    "你是一位写中文俳句的诗人。用户给你一封信的正文，"
    "你从中提取最有代表性的意象，写一首中文俳句：三行，遵循 5-7-5 音节的意境"
    "（不必严格数字数，但必须三行、克制、留白）。"
    "句中必须包含一个季语（体现季节的自然意象，如春樱、蝉鸣、落叶、初雪），"
    "季语优先取自信件正文本身的意象，正文没有合适意象时再按信件语境另选。"
    "不要直接复述正文，只取意象。只输出俳句本身，不要标题、引号或任何解释。"
)

_DISABLE_MESSAGE = "AI 辅助当前不可用，可以直接手写这封信"

# 推理模型（deepseek 等）的思考过程也计入 max_tokens（B7 结论），
# 实测思考可轻松吃掉上千 token（finish_reason=length、content 为空），
# 所以统一给足预算；网关不支持 enable_thinking=false。
REASONING_MAX_TOKENS = 4096


def _require_enabled() -> None:
    if not get_settings().feature_ai:
        raise FeatureDisabled(_DISABLE_MESSAGE)


def _text_from_blocks(blocks: list[dict]) -> str:
    """从图文交替流中提取纯正文（只拼 text 块）。"""
    return " ".join(b["text"] for b in blocks if b.get("type") == "text")


async def _generate(system_prompt: str, blocks: list[dict], max_tokens: int) -> str:
    """共用生成路径：配置缺失、正文为空、调用失败 → 一律 FeatureDisabled。"""
    _require_enabled()

    settings = get_settings()
    if not (settings.openai_api_key and settings.openai_base_url and settings.openai_model):
        raise FeatureDisabled(_DISABLE_MESSAGE)

    text = _text_from_blocks(blocks).strip()
    if not text:
        raise FeatureDisabled(_DISABLE_MESSAGE)

    result = await chat_completion(
        [{"role": "system", "content": system_prompt}, {"role": "user", "content": text}],
        max_tokens=max_tokens,
    )
    if result is None:
        raise FeatureDisabled(_DISABLE_MESSAGE)
    return result


async def polish(blocks: list[dict]) -> str:
    """润色正文，保留原意。

    契约：调用失败/超时时同样抛 FeatureDisabled，让前端降级，**不要抛 500**。
    """
    return await _generate(POLISH_SYSTEM_PROMPT, blocks, max_tokens=REASONING_MAX_TOKENS)


async def compose_poem(blocks: list[dict]) -> str:
    """从正文提取意象生成俳句（默认体裁，三行）。失败时同上降级。"""
    # 推理模型的思考过程也消耗 max_tokens（B7 结论），给足预算避免 content 为空
    return await _generate(POEM_SYSTEM_PROMPT, blocks, max_tokens=REASONING_MAX_TOKENS)
