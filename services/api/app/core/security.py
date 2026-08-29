"""JWT 签发与校验。

PRD 6.13：设备绑定优先、账号可选、全程无强制注册。
JWT payload 只含 `sub`(user_id) 与 `exp`——**不放任何画像信息**（PRD §8.1 数据最小化）。

管理端（AdminAccount）与匿名用户体系完全隔离：admin token 的 payload
额外带 `typ: "admin"`，decode_admin_token 拒绝普通 user token，反之亦然。
"""

import hashlib
import hmac
import secrets
from datetime import UTC, datetime, timedelta
from uuid import UUID

import jwt

from app.core.config import get_settings
from app.core.errors import Unauthorized

# 密码哈希：stdlib pbkdf2，不引第三方依赖。存储格式
# `pbkdf2_sha256$<iterations>$<salt_hex>$<hash_hex>`，迭代数随行存，可平滑升级。
_PBKDF2_ITERATIONS = 240_000
_PBKDF2_ALGO = "sha256"


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac(_PBKDF2_ALGO, password.encode(), salt, _PBKDF2_ITERATIONS)
    return f"pbkdf2_{_PBKDF2_ALGO}${_PBKDF2_ITERATIONS}${salt.hex()}${digest.hex()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        algo, iterations, salt_hex, hash_hex = stored.split("$")
        if algo != f"pbkdf2_{_PBKDF2_ALGO}":
            return False
        digest = hashlib.pbkdf2_hmac(
            _PBKDF2_ALGO, password.encode(), bytes.fromhex(salt_hex), int(iterations)
        )
    except (ValueError, TypeError):
        return False
    return hmac.compare_digest(digest.hex(), hash_hex)


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
    """返回 user_id；token 无效或过期抛 Unauthorized。admin token 冒用同样拒绝。"""
    payload = _decode(token)
    if payload.get("typ") == "admin":
        raise Unauthorized("管理端凭证不可用于用户接口")
    return _parse_subject(payload)


def create_admin_token(admin_id: UUID) -> str:
    settings = get_settings()
    now = datetime.now(UTC)
    payload = {
        "sub": str(admin_id),
        "typ": "admin",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=settings.admin_jwt_expire_minutes)).timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_admin_token(token: str) -> UUID:
    """返回 admin_id；user token 冒用（无 typ=admin）同样拒绝。"""
    payload = _decode(token)
    if payload.get("typ") != "admin":
        raise Unauthorized("非管理端凭证")
    return _parse_subject(payload)


def _parse_subject(payload: dict[str, object]) -> UUID:
    sub = payload.get("sub")
    if not isinstance(sub, str) or not sub:
        raise Unauthorized("身份凭证缺少主体")
    try:
        return UUID(sub)
    except ValueError as exc:
        raise Unauthorized("身份凭证格式错误") from exc


def _decode(token: str) -> dict[str, object]:
    settings = get_settings()
    try:
        payload: dict[str, object] = jwt.decode(
            token, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
        )
    except jwt.ExpiredSignatureError as exc:
        raise Unauthorized("登录已过期，请重新进入") from exc
    except jwt.InvalidTokenError as exc:
        raise Unauthorized("无效的身份凭证") from exc
    return payload
