"""JWT 签发与校验。

PRD 6.13：设备绑定优先、账号可选、全程无强制注册。
JWT payload 只含 `sub`(user_id) 与 `exp`——**不放任何画像信息**（PRD §8.1 数据最小化）。
"""

from datetime import UTC, datetime, timedelta
from uuid import UUID

import jwt

from app.core.config import get_settings
from app.core.errors import Unauthorized


def create_access_token(user_id: UUID) -> str:
    settings = get_settings()
    now = datetime.now(UTC)
    payload = {
        "sub": str(user_id),
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(days=settings.jwt_expire_days)).timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> UUID:
    """返回 user_id；token 无效或过期抛 Unauthorized。"""
    settings = get_settings()
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    except jwt.ExpiredSignatureError as exc:
        raise Unauthorized("登录已过期，请重新进入") from exc
    except jwt.InvalidTokenError as exc:
        raise Unauthorized("无效的身份凭证") from exc

    sub = payload.get("sub")
    if not sub:
        raise Unauthorized("身份凭证缺少主体")
    try:
        return UUID(sub)
    except ValueError as exc:
        raise Unauthorized("身份凭证格式错误") from exc
