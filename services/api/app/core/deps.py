"""FastAPI 依赖。

CurrentUser  — 必须登录（设备绑定即算登录）
OptionalUser — 可匿名访问，用于不需要身份的读取路径
"""

from typing import Annotated
from uuid import UUID

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.errors import Unauthorized
from app.core.security import decode_access_token

_bearer = HTTPBearer(auto_error=False)
_bearer_optional = HTTPBearer(auto_error=False)

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
