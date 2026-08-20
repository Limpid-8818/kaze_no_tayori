"""pytest 公共 fixture。

不需要数据库的测试直接打 ASGI app（不起真实服务器）。
需要真 PostGIS 的测试标记 `@pytest.mark.db`，由 `make check-db` 单独跑——
这样本机离线/云库未就绪时，纯逻辑测试照样能跑。
"""

from collections.abc import AsyncGenerator

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
