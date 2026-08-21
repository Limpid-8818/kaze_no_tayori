"""认证（PRD 6.13）。

设备绑定优先、账号可选、全程无强制注册。
展示层永不暴露账户——账户只为跨设备、我的信、抄本、回信通知服务。
"""

from fastapi import APIRouter

from app.core.deps import Session
from app.core.security import create_access_token
from app.schemas.common import DeviceAuthRequest, TokenResponse
from app.services import account_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/device", response_model=TokenResponse)
async def bind_device(payload: DeviceAuthRequest, session: Session) -> TokenResponse:
    """用客户端生成的 device_id 换取长效 JWT。无密码。

    首次调用时 upsert 一个 users 行。
    """
    user = await account_service.upsert_by_device(session, payload.device_id)
    return TokenResponse(
        access_token=create_access_token(user.id),
        user_id=user.id,
    )
