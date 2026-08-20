"""健康检查与契约面的骨架测试。

`/health` 刻意不碰数据库——云库未就绪时后端依然能起、前端依然能联调。
"""

import pytest
from httpx import AsyncClient


async def test_health_does_not_touch_db(client: AsyncClient) -> None:
    resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


async def test_openapi_schema_builds(client: AsyncClient) -> None:
    """OpenAPI 能生成，说明全部 router 与 schema 自洽。"""
    resp = await client.get("/openapi.json")
    assert resp.status_code == 200
    assert len(resp.json()["paths"]) >= 20


@pytest.mark.parametrize(
    "path",
    [
        "/v1/letters",
        "/v1/drift/next",
        "/v1/discover",
        "/v1/me/letters",
        "/v1/me/scripbook",
        "/v1/me/notifications",
        "/v1/themes",
        "/v1/tags",
    ],
)
async def test_core_endpoints_are_registered(client: AsyncClient, path: str) -> None:
    """核心 endpoint 已在契约中登记（脚手架阶段只验存在，不验行为）。"""
    schema = (await client.get("/openapi.json")).json()
    assert path in schema["paths"]


async def test_forbidden_endpoints_absent(client: AsyncClient) -> None:
    """明确不存在的接口（CLAUDE.md 红线 2 / API_CONTRACT.md §4）。

    这些路径一旦出现，说明有人在往社交产品的方向走。
    """
    schema = (await client.get("/openapi.json")).json()
    paths = " ".join(schema["paths"])
    for banned in ("like", "follow", "feed", "trending", "ranking", "leaderboard", "message"):
        assert banned not in paths, f"出现了被禁止的接口语义：{banned}"
