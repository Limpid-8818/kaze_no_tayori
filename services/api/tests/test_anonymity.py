"""匿名铁律的机械化守卫（CLAUDE.md 红线 1 / PRD §7.1）。

这些测试的存在意义：把「展示层永不渲染作者信息」从一条人类需要记住的纪律，
变成一条**加回作者字段就会变红**的约束。

如果你正因为这个文件报错而读到这里：不要改测试，改回你的 schema。
读者可达作者是产品红线，不是实现细节。
"""

import pytest

from app.schemas.letter import LetterOwned, LetterPublic

# 任何形如作者标识的字段名都不许出现在对外 schema 里
FORBIDDEN_FIELDS = {
    "owner_user_id",
    "owner",
    "user_id",
    "author",
    "author_id",
    "author_name",
    "anon_id",
    "nickname",
    "avatar",
    "avatar_url",
    "profile",
    "profile_url",
    "device_id",
    "email",
}

# 社交度量语义的字段名同样不许出现（红线 2）
FORBIDDEN_METRIC_FIELDS = {
    "likes",
    "like_count",
    "liked",
    "followers",
    "follower_count",
    "following",
    "score",
    "hot",
    "hotness",
    "rank",
    "ranking",
    "trending",
}


@pytest.mark.parametrize("schema", [LetterPublic, LetterOwned])
def test_letter_schemas_expose_no_author_identity(schema: type) -> None:
    leaked = FORBIDDEN_FIELDS & set(schema.model_fields)
    assert not leaked, (
        f"{schema.__name__} 泄漏了作者标识字段 {leaked}。"
        "信件展示层永不渲染作者信息（PRD §7.1），请改回 schema 而不是改这个测试。"
    )


@pytest.mark.parametrize("schema", [LetterPublic, LetterOwned])
def test_letter_schemas_have_no_social_metrics(schema: type) -> None:
    leaked = FORBIDDEN_METRIC_FIELDS & set(schema.model_fields)
    assert not leaked, (
        f"{schema.__name__} 出现了社交度量字段 {leaked}。"
        "不点赞、不关注、不排行（PRD §7.2）；计数只有 read/resonance/voice/reply/saved。"
    )


def test_public_letter_exposes_drop_point_coordinates() -> None:
    """落点坐标是公开的创作元素（2026-08 用户裁决）：对外响应带 lat/lon，
    供读者计算与自己的直线距离；location 原始列与作者标识仍然缺席。"""
    assert "lat" in LetterPublic.model_fields
    assert "lon" in LetterPublic.model_fields
    assert "location" not in LetterPublic.model_fields
    assert "place_label" in LetterPublic.model_fields

    # 本人视角（LetterOwned）坐标继承自 LetterPublic
    assert "lat" in LetterOwned.model_fields
    assert "lon" in LetterOwned.model_fields


def test_counts_are_exactly_the_five_narrative_counters() -> None:
    """叙事计数只有 5 个，不许扩张（PRD §7.4）。"""
    from app.schemas.letter import LetterCounts

    assert set(LetterCounts.model_fields) == {"read", "resonance", "voice", "reply", "saved"}


def test_music_ref_is_quotation_only() -> None:
    """音乐只有专辑+歌曲+歌词三个字符串（PRD §7.7）。

    不生成、不上传、不外链——出现任何 url/audio 字段即违规。
    """
    from app.schemas.letter import MusicRef

    assert set(MusicRef.model_fields) == {"album", "song", "lyrics"}
