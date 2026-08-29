"""反馈链路离线测试：请求校验、鉴权边界、密码哈希与 token 隔离。

不碰数据库：提交入库的行为在 test_feedback_db.py。
"""

import uuid

import pytest
from fastapi import status
from httpx import AsyncClient

from app.core.errors import Unauthorized
from app.core.security import (
    create_access_token,
    create_admin_token,
    decode_access_token,
    decode_admin_token,
    hash_password,
    verify_password,
)


def _user_headers() -> dict[str, str]:
    token = create_access_token(uuid.uuid4())
    return {"Authorization": f"Bearer {token}"}


# ---------- 请求校验（422 在落库前，离线可测）----------
@pytest.mark.parametrize(
    "body",
    [
        # category 非法
        {"category": "complaint", "content": "不能上传图片"},
        # content 空
        {"category": "bug", "content": ""},
        # content 只含空白
        {"category": "bug", "content": "   "},
        # content 超长（2001 字）
        {"category": "suggestion", "content": "好" * 2001},
    ],
)
async def test_submit_feedback_validation_422(client: AsyncClient, body: dict) -> None:
    resp = await client.post("/v1/feedback", json=body, headers=_user_headers())
    assert resp.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


async def test_submit_feedback_requires_auth(client: AsyncClient) -> None:
    resp = await client.post("/v1/feedback", json={"category": "bug", "content": "闪退"})
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED


# ---------- 密码哈希 ----------
def test_password_hash_roundtrip() -> None:
    stored = hash_password("s3cret-pass")
    assert stored.startswith("pbkdf2_sha256$")
    assert verify_password("s3cret-pass", stored)
    assert not verify_password("wrong-pass", stored)


def test_password_hash_unique_salt() -> None:
    assert hash_password("same") != hash_password("same")


# ---------- token 体系隔离 ----------
def test_admin_token_rejected_as_user_token() -> None:
    admin_token = create_admin_token(uuid.uuid4())
    with pytest.raises(Unauthorized):
        decode_access_token(admin_token)


def test_user_token_rejected_as_admin_token() -> None:
    user_token = create_access_token(uuid.uuid4())
    with pytest.raises(Unauthorized):
        decode_admin_token(user_token)
