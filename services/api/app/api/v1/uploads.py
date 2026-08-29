"""图片上传（PRD 6.1）。

明信片式：1 张为主，最多 3 张。压缩后存储，只把 URL 写进信件。
STORAGE_BACKEND=local 时落盘到仓库根 uploads/（已 gitignore），s3 时走对象存储。
"""

from typing import Annotated

from fastapi import APIRouter, File, UploadFile

from app.core.deps import ActorId
from app.core.errors import UnsupportedImageType
from app.schemas.common import UploadResponse
from app.services import storage_service

router = APIRouter(prefix="/uploads", tags=["uploads"])

_ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}


@router.post("/images", response_model=UploadResponse, status_code=201)
async def upload_image(
    actor_id: ActorId,
    file: Annotated[UploadFile, File()],
) -> UploadResponse:
    """上传单张图片，返回可公开访问的 URL。

    存储不可用时降级为本地磁盘——图片失败不应阻断写信主流程。
    身份放宽为 user 或 admin JWT 均可（运营控制台传图，2026-08-29 裁决）。
    """
    if file.content_type not in _ALLOWED_CONTENT_TYPES:
        raise UnsupportedImageType("仅支持 JPEG / PNG / WebP 图片")
    data = await file.read()
    url = await storage_service.save_image(data, file.filename or "")
    return UploadResponse(url=url)
