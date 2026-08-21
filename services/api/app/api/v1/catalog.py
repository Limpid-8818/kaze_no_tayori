"""静态目录：主题皮肤与思绪标签（PRD 6.9 / 6.8）。

无需认证。纯读取，无外部依赖，不参与降级。
B1 阶段直接静态返回，不查库；与 scripts/seed_letters.py 的 THEMES/TAGS 保持同步。
"""

from fastapi import APIRouter

from app.schemas.common import TagPublic, ThemePublic

router = APIRouter(tags=["catalog"])

# 主题皮肤：P0 只有「夏」。皮肤一旦被信件选定即永久绑定，不做季节迁移
THEMES: list[ThemePublic] = [
    ThemePublic(id="natsu", name="夏", assets={}, is_default=True),
]

# 预置思绪标签（PRD 6.8，P1）
TAGS: list[TagPublic] = [
    TagPublic(id="travel", name="旅途", color="#7FA88B"),
    TagPublic(id="night", name="夜色", color="#2B3A55"),
    TagPublic(id="sea", name="海", color="#5B8FB9"),
    TagPublic(id="miss", name="想念", color="#E8836F"),
    TagPublic(id="alone", name="独处", color="#55617D"),
    TagPublic(id="summer", name="夏天", color="#FFD98E"),
]


@router.get("/themes", response_model=list[ThemePublic])
async def list_themes() -> list[ThemePublic]:
    """主题皮肤列表。P0 只有「夏」natsu。

    皮肤一旦被信件选定即永久绑定，此接口只提供可选项，不影响历史信件。
    """
    return THEMES


@router.get("/tags", response_model=list[TagPublic])
async def list_tags() -> list[TagPublic]:
    """预置思绪标签，写信时可选 1–3 个。"""
    return TAGS
