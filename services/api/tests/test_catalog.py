"""catalog：静态目录接口（无 DB 依赖）。"""

import pytest


@pytest.mark.parametrize("path", ["/v1/themes", "/v1/tags"])
async def test_catalog_ok(client, path):  # type: ignore[no-untyped-def]
    resp = await client.get(path)
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


async def test_themes_contains_natsu(client):  # type: ignore[no-untyped-def]
    resp = await client.get("/v1/themes")
    assert resp.status_code == 200
    themes = resp.json()
    assert any(t["id"] == "natsu" and t["is_default"] is True and t["name"] == "夏" for t in themes)


async def test_tags_preset(client):  # type: ignore[no-untyped-def]
    resp = await client.get("/v1/tags")
    assert resp.status_code == 200
    tags = resp.json()
    ids = {t["id"] for t in tags}
    assert ids == {"travel", "night", "sea", "miss", "alone", "summer"}
