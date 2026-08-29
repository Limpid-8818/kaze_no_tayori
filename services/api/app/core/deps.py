"""FastAPI 依赖。

CurrentUser  — 必须登录（设备绑定即算登录）
OptionalUser — 可匿名访问，用于不需要身份的读取路径
CurrentAdmin — 管理端专用（AdminAccount 密码登录换取的 typ=admin JWT）
"""

from typing import Annotated
from uuid import UUID

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.errors import Unauthorized
from app.core.security import decode_access_token, decode_admin_token
from app.models.report import AdminAccount

_bearer = HTTPBearer(auto_error=False)
_bearer_optional = HTTPBearer(auto_error=False)
_bearer_admin = HTTPBearer(auto_error=False)

Session = Annotated[AsyncSession, Depends(get_session)]


async def current_user_id(
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> UUID:
    if creds is None:
        raise Unauthorized("缺少身份凭证")
    return decode_access_token(creds.credentials)


async def optional_user_id(
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer_optional)],
) -> UUID | None:
    if creds is None:
        return None
    try:
        return decode_access_token(creds.credentials)
    except Unauthorized:
        return None


CurrentUser = Annotated[UUID, Depends(current_user_id)]
OptionalUser = Annotated[UUID | None, Depends(optional_user_id)]


async def current_admin_id(
    session: Session, creds: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer_admin)]
) -> UUID:
    """管理端身份：typ=admin 的 JWT，且账号仍存在于 admin_accounts。"""
    if creds is None:
        raise Unauthorized("缺少管理端凭证")
    admin_id = decode_admin_token(creds.credentials)
    row = await session.scalar(select(AdminAccount.id).where(AdminAccount.id == admin_id))
    if row is None:
        raise Unauthorized("管理账号不存在")
    return admin_id


CurrentAdmin = Annotated[UUID, Depends(current_admin_id)]
