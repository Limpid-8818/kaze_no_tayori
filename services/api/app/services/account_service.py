"""账户服务（模块②，PRD 6.13）。

账户存在只为支撑跨设备、「我的信」、抄本、回信通知。
**发布层永远匿名**：owner_user_id 仅服务端管理用，展示层永不渲染。
"""

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


async def upsert_by_device(session: AsyncSession, device_id: str) -> User:
    """用 device_id 换取（或创建）用户。无密码、无强制注册。

    契约：ON CONFLICT (device_id) DO NOTHING 后回查，保证并发下幂等。
    不写入任何画像字段（PRD §8.1 数据最小化）。
    """
    raise NotImplementedError


async def get_user(session: AsyncSession, user_id: UUID) -> User:
    """按 id 取用户，不存在抛 NotFound。"""
    raise NotImplementedError
