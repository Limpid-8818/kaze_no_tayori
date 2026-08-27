"""OpenAI 兼容 chat 客户端（B7，AI 短诗 / LLM 审核共用）。

最小封装：只做 chat completions，不做流式/工具调用。
契约：任何失败（网络/超时/非 200/解析失败/空 content）一律返回 None，
由调用方决定降级方向——AI 抛 FeatureDisabled，审核落 PENDING。
"""

from __future__ import annotations

import logging

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)


def _normalize_base_url(base_url: str) -> str:
    """确保 base_url 带协议头且不带尾部斜杠，避免拼接出双斜杠。"""
    base_url = base_url.strip().rstrip("/")
    if not base_url.startswith(("http://", "https://")):
        return f"https://{base_url}"
    return base_url


async def chat_completion(
    messages: list[dict],
    *,
    max_tokens: int = 512,
    temperature: float = 0.7,
) -> str | None:
    """调用 OpenAI 兼容接口，返回 assistant 文本；失败返回 None。"""
    settings = get_settings()
    if not (settings.openai_api_key and settings.openai_base_url and settings.openai_model):
        return None

    url = f"{_normalize_base_url(settings.openai_base_url)}/chat/completions"
    headers = {"Authorization": f"Bearer {settings.openai_api_key}"}
    payload = {
        "model": settings.openai_model,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
    }

    # 推理模型（deepseek 等）思考耗时长，15s 会频繁超时
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(url, json=payload, headers=headers)
    except (OSError, httpx.TimeoutException, httpx.ConnectError, httpx.RequestError) as exc:
        logger.warning("LLM 请求异常: %r", exc)
        return None

    if resp.status_code != 200:
        logger.warning("LLM 返回非 200: status=%s body=%s", resp.status_code, resp.text[:500])
        return None

    try:
        data = resp.json()
        content = data["choices"][0]["message"]["content"]
    except Exception:
        logger.warning("LLM 响应解析失败: body=%s", resp.text[:500])
        return None

    if not isinstance(content, str) or not content.strip():
        logger.warning(
            "LLM content 为空（可能 reasoning 耗尽 max_tokens）: finish_reason=%s",
            data.get("choices", [{}])[0].get("finish_reason"),
        )
        return None
    return content.strip()
