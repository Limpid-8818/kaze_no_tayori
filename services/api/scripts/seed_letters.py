"""种子数据：静态目录 + 冷启动种子信。

用法：make seed

为什么需要：漂流池空的时候，第一个用户抽不到任何信，核心循环走不通。
PRD 6.14 的运营控制台是 P1，P0 阶段由这个脚本承担冷启动职责。

脚手架阶段只搭好骨架与调用契约，种子信内容待定（PRD 6.14 明确「具体种子信内容待定」）。
"""

import asyncio
import sys

from app.core.db import SessionLocal

# ---------- 静态目录 ----------
# 主题皮肤：P0 只有「夏」。皮肤一旦被信件选定即永久绑定，不做季节迁移
THEMES: list[dict[str, object]] = [
    {"id": "natsu", "name": "夏", "assets": {}, "is_default": True},
]

# 预置思绪标签（PRD 6.8，P1）
TAGS: list[dict[str, str]] = [
    {"id": "travel", "name": "旅途", "color": "#7FA88B"},
    {"id": "night", "name": "夜色", "color": "#2B3A55"},
    {"id": "sea", "name": "海", "color": "#5B8FB9"},
    {"id": "miss", "name": "想念", "color": "#E8836F"},
    {"id": "alone", "name": "独处", "color": "#55617D"},
    {"id": "summer", "name": "夏天", "color": "#FFD98E"},
]

# ---------- 冷启动种子信 ----------
# 内容待定。约定：
# - 每封都要有 place_label / weather，体现「地点·时间·天气」的锚点
# - drift 与 stay 都要有（两者都是一等公民）
# - owner_user_id 留空：种子信没有作者，天然符合匿名精神
# - status 直接置 public（种子信不走机审）
SEED_LETTERS: list[dict[str, object]] = []


async def main() -> int:
    print("=== Kaze no tayori - seed ===")
    async with SessionLocal() as session:
        print(f"  themes  : {len(THEMES)} (upsert)")
        print(f"  tags    : {len(TAGS)} (upsert)")
        print(f"  letters : {len(SEED_LETTERS)} (insert)")
        # TODO(scaffold): upsert THEMES/TAGS, insert SEED_LETTERS with
        # location = ST_MakePoint(lon, lat)::geography for stay letters.
        _ = session
        raise NotImplementedError(
            "seed logic not implemented yet - scaffold only (see PRD 6.14: seed content TBD)"
        )


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
