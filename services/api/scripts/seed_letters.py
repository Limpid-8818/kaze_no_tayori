"""种子数据：静态目录 + 冷启动种子信。

用法：make seed

为什么需要：漂流池空的时候，第一个用户抽不到任何信，核心循环走不通。
PRD 6.14 的运营控制台是 P1，P0 阶段由这个脚本承担冷启动职责。

种子信内容：12 封，全部国内坐标，无 owner，直接 public。
drift 8 封 + stay 4 封，place_label 与逆地理服务同口径：
「 · 」分隔的纯名字（不带行政后缀，直辖市只到「市 · 区」）。
"""

import asyncio
import json
import sys
from uuid import uuid4

from geoalchemy2 import WKTElement
from sqlalchemy import text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import SessionLocal
from app.models.catalog import Theme, ThoughtTag
from app.models.enums import LetterStatus

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
# 约定：
# - 每封都要有 place_label / weather，体现「地点·时间·天气」的锚点
# - drift 与 stay 都有（两者都是一等公民）
# - owner_user_id 留空：种子信没有作者，天然符合匿名精神
# - status 直接置 public（种子信不走机审）
# - music_ref 留空：种子信不需要音乐引用
def _letter(
    place_label: str,
    weather: dict[str, object],
    delivery_mode: str,
    tags: list[str],
    blocks: list[dict[str, object]],
    lat: float | None = None,
    lon: float | None = None,
) -> dict[str, object]:
    """构造一封种子信的字典。

    stay 模式需要 lat/lon，写入 PostGIS geography(POINT)。
    drift 模式 lat/lon 传 None，location 留空。
    """
    location = None
    if delivery_mode == "stay" and lat is not None and lon is not None:
        # extended=True → EWKB，与 geography 列直接兼容（同 letter_service.py）
        location = WKTElement(f"POINT({lon} {lat})", srid=4326, extended=True)

    return {
        "id": uuid4(),
        "blocks": blocks,
        "poem": None,
        "theme_id": "natsu",
        "theme_skin": None,
        "music_ref": None,
        "tags": tags,
        "location": location,
        "place_label": place_label,
        "weather": weather,
        "delivery_mode": delivery_mode,
        "status": LetterStatus.PUBLIC,
        "owner_user_id": None,
        "parent_letter_id": None,
        "expire_at": None,
        "read_count": 0,
        "resonance_count": 0,
        "voice_count": 0,
        "reply_count": 0,
        "saved_count": 0,
    }


SEED_LETTERS: list[dict[str, object]] = [
    # ── DRIFT ──
    # D-01 栈桥的傍晚 — 山东 · 青岛
    _letter(
        place_label="山东 · 青岛",
        weather={"text": "晴", "temp_c": 27, "icon": "clear"},
        delivery_mode="drift",
        tags=["sea", "summer", "travel"],
        blocks=[
            {
                "type": "text",
                "text": "青岛的傍晚，栈桥尽头的水比天空更蓝。海风把头发吹得看不清路。照片存在手机里没发出去。现在它漂出来了。如果你也在看海，说明我们曾在同一片蓝色里。不需要更多。",
            }
        ],
    ),
    # D-02 凌晨的便利店 — 四川 · 成都
    _letter(
        place_label="四川 · 成都",
        weather={"text": "多云", "temp_c": 22, "icon": "cloudy"},
        delivery_mode="drift",
        tags=["night", "alone", "miss"],
        blocks=[
            {
                "type": "text",
                "text": "凌晨两点，便利店的灯光比路灯更让人安心。红豆面包还是热的，我买了两份，自己吃了一份。另一份留在台阶上拍了张照片，没有发给任何人。这句话也是。如果你也曾在深夜的便利店门口坐过，这就是我们之间的默契。",
            }
        ],
    ),
    # D-03 末班地铁 — 重庆 · 渝中
    _letter(
        place_label="重庆 · 渝中",
        weather={"text": "小雨", "temp_c": 19, "icon": "rain"},
        delivery_mode="drift",
        tags=["night", "alone", "summer"],
        blocks=[
            {
                "type": "text",
                "text": "末班地铁的窗上，我的倒影和站台灯光一起摇晃。我写了几行字又删了。最后留下的只有一句：如果你也在深夜的地铁上，请把窗外的霓虹当成这封信的邮戳。它会带你到某处。",
            }
        ],
    ),
    # D-04 老巷 — 云南 · 大理
    _letter(
        place_label="云南 · 大理",
        weather={"text": "晴", "temp_c": 18, "icon": "clear"},
        delivery_mode="drift",
        tags=["travel", "alone", "summer"],
        blocks=[
            {
                "type": "text",
                "text": "大理的老巷子里，午后的光从瓦缝里漏下来，照在青石板上。旁边的人家养了一只三花猫，它在门槛上看了我一眼又睡了。我把这句话留在这里——不是给后来的人，是给这个即将变暗的瞬间。它不需要被谁接住。",
            }
        ],
    ),
    # D-05 长江大桥 — 湖北 · 武汉
    _letter(
        place_label="湖北 · 武汉",
        weather={"text": "多云", "temp_c": 24, "icon": "cloudy"},
        delivery_mode="drift",
        tags=["summer", "travel", "night"],
        blocks=[
            {
                "type": "text",
                "text": "武汉长江大桥的夜景是黄色的。桥上有人在拍延时，我在看江水。风里有汽渡的味道。我突然想写点什么，于是写了这句。不知道你会从哪里读到它——也许在另一座桥上，也许在某个下雨的下午。反正我们都在水边。这就够了。",
            }
        ],
    ),
    # D-06 路灯下 — 上海 · 静安
    _letter(
        place_label="上海 · 静安",
        weather={"text": "小雨", "temp_c": 20, "icon": "rain"},
        delivery_mode="drift",
        tags=["night", "miss", "alone"],
        blocks=[
            {
                "type": "text",
                "text": "十字路口的信号灯变换了三次，我还在同一个地方。对面的人换了两拨，我没有动。我想，此刻世界上一定有人正站在某个路口等着绿灯——你也是其中之一吧？这封信给等灯的你。",
            }
        ],
    ),
    # D-07 山顶 — 陕西 · 华山
    _letter(
        place_label="陕西 · 华山",
        weather={"text": "晴", "temp_c": 21, "icon": "clear"},
        delivery_mode="drift",
        tags=["travel", "summer", "miss"],
        blocks=[
            {
                "type": "text",
                "text": "从华山往下看，整个关中只是一片灰白色的屋顶。风把松涛声吹得很远，远到听不见。我在这里坐了四十分钟，什么都没想。只是觉得——这个景色不需要被谁看见，它本身就是完整的。这封信也是。如果你也在高处，往下看的时候，请知道此刻有个人和你看着同一个方向。",
            }
        ],
    ),
    # D-08 电话亭 — 黑龙江 · 哈尔滨
    _letter(
        place_label="黑龙江 · 哈尔滨",
        weather={"text": "晴", "temp_c": 15, "icon": "clear"},
        delivery_mode="drift",
        tags=["alone", "night", "miss"],
        blocks=[
            {
                "type": "text",
                "text": "哈尔滨冬天的电话亭，玻璃上全是霜。我在里面待了三分钟，没有打电话。外面的风大到整座亭子在轻微摇晃。我想，这封信就是那朵干花。不需要水，不需要土壤，就这样飘着。如果某天它落在你手里，说明风的方向是对的。",
            }
        ],
    ),
    # ── STAY ──
    # S-01 埋在海边 — 福建 · 厦门
    _letter(
        place_label="福建 · 厦门",
        weather={"text": "晴", "temp_c": 27, "icon": "clear"},
        delivery_mode="stay",
        lat=24.4448,
        lon=118.0820,
        tags=["sea", "summer", "miss"],
        blocks=[
            {
                "type": "text",
                "text": "如果你正站在厦门的环岛路上，面朝大海，有一块被浪拍得最勤的礁石。我今年夏天在这里坐了两个小时。海浪把贝壳推到脚边，又把它们带走。我把这句话留在这块礁石附近的空气里——如果你也来了，请对着海站三十秒。那三十秒里，我们共享同一种蓝。二零二四年八月，某个陌生的写信人。",
            }
        ],
    ),
    # S-02 图书馆的窗边 — 浙江 · 杭州
    _letter(
        place_label="浙江 · 杭州",
        weather={"text": "多云", "temp_c": 23, "icon": "cloudy"},
        delivery_mode="stay",
        lat=30.2741,
        lon=120.1506,
        tags=["alone", "summer", "miss"],
        blocks=[
            {
                "type": "text",
                "text": "杭州图书馆的二楼靠窗位置，下午三点的光线刚好落在书脊上。我在这里待了一整个下午，同一本书翻了三页。旁边的人换了三波。如果你也来过这个位置，请帮我看一眼窗外的梧桐——现在是不是已经开始黄了？如果是的话，这封信的使命就完成了。",
            }
        ],
    ),
    # S-03 岛上 — 海南 · 三亚
    _letter(
        place_label="海南 · 三亚",
        weather={"text": "晴", "temp_c": 28, "icon": "clear"},
        delivery_mode="stay",
        lat=18.2524,
        lon=109.5080,
        tags=["travel", "sea", "summer"],
        blocks=[
            {
                "type": "text",
                "text": "三年前我来过这座岛，在一个同样晴朗的午后，拍了一张照片。照片存在手机里，没有发给任何人。三年后的今天，我把这句话埋在这个岛上。如果你偶然读到，说明你和我走在同一片沙滩上。请替我看一眼岛上的椰树——它们应该还在海边晃着。",
            }
        ],
    ),
    # S-04 月台 — 湖南 · 张家界
    _letter(
        place_label="湖南 · 张家界",
        weather={"text": "晴", "temp_c": 24, "icon": "clear"},
        delivery_mode="stay",
        lat=29.1249,
        lon=110.4792,
        tags=["travel", "miss", "alone"],
        blocks=[
            {
                "type": "text",
                "text": "张家界的缆车站不是终点。我把这句话留在这里，不是留给某个特定的人，是留给每一个「在终点之前下车」的人。如果你也在这个站台犹豫过要不要往前走，请相信——那个夏天的某个人，和你共享过同一份犹豫。这封信替他们说了声：继续走吧。",
            }
        ],
    ),
]


# ---------- upsert helpers ----------


async def upsert_themes(session: AsyncSession, themes: list[dict[str, object]]) -> int:
    """Upsert themes 表。ON CONFLICT (id) DO NOTHING，幂等。"""
    stmt = pg_insert(Theme).values(themes).on_conflict_do_nothing(index_elements=["id"])
    result = await session.execute(stmt)
    return result.rowcount  # type: ignore[return-value]


async def upsert_tags(session: AsyncSession, tags: list[dict[str, str]]) -> int:
    """Upsert thought_tags 表。ON CONFLICT (id) DO NOTHING，幂等。"""
    stmt = pg_insert(ThoughtTag).values(tags).on_conflict_do_nothing(index_elements=["id"])
    result = await session.execute(stmt)
    return result.rowcount  # type: ignore[return-value]


async def insert_seed_letters(session: AsyncSession, letters: list[dict[str, object]]) -> int:
    """插入种子信。

    每次执行生成新 UUID，不做内容去重（种子信是多份存在的）。
    直接 public，不走审核。
    JSONB 字段需要显式序列化为 JSON 字符串再传入裸 SQL。
    """
    count = 0
    for letter_data in letters:
        # 构造 INSERT 语句，WKTElement  geography 值用 text() 包裹的 bindparam
        stmt = text(
            """
            INSERT INTO letters (
                id, blocks, poem, theme_id, theme_skin, music_ref, tags,
                location, place_label, weather,
                delivery_mode, status, owner_user_id, parent_letter_id, expire_at,
                read_count, resonance_count, voice_count, reply_count, saved_count
            ) VALUES (
                :id, :blocks, :poem, :theme_id, :theme_skin, :music_ref, :tags,
                :location, :place_label, :weather,
                :delivery_mode, :status, :owner_user_id, :parent_letter_id, :expire_at,
                :read_count, :resonance_count, :voice_count, :reply_count, :saved_count
            )
            """
        )
        # 显式序列化 JSONB 字段，避免 asyncpg 的 JSONB encoder 报错
        serialized = {
            **letter_data,
            "blocks": json.dumps(letter_data["blocks"], ensure_ascii=False),
            "tags": json.dumps(letter_data["tags"], ensure_ascii=False),
            "weather": json.dumps(letter_data["weather"], ensure_ascii=False),
            "music_ref": json.dumps(letter_data["music_ref"]) if letter_data["music_ref"] else None,
            "theme_skin": json.dumps(letter_data["theme_skin"])
            if letter_data["theme_skin"]
            else None,
            "poem": letter_data["poem"],
            # WKTElement → WKT 字符串，让 PostGIS 的 geography 类型接收
            "location": letter_data["location"].desc if letter_data["location"] else None,
            # Enum → 字符串值
            "status": letter_data["status"].value,
        }
        await session.execute(stmt, serialized)
        count += 1
    return count


# ---------- main ----------


async def main() -> int:
    print("=== Kaze no tayori - seed ===")
    async with SessionLocal() as session:
        theme_count = await upsert_themes(session, THEMES)
        tag_count = await upsert_tags(session, TAGS)
        letter_count = await insert_seed_letters(session, SEED_LETTERS)
        await session.commit()
        print(f"  themes  : {theme_count} (upsert)")
        print(f"  tags    : {tag_count} (upsert)")
        print(f"  letters : {letter_count} (insert)")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
