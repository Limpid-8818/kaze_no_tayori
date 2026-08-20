"""图片上传（PRD 6.1）。

明信片式：1 张为主，最多 3 张。压缩后存储，只把 URL 写进信件。
STORAGE_BACKEND=local 时落盘到仓库根 uploads/（已 gitignore），s3 时走对象存储。
"""

from typing import Annotated

from fastapi import APIRouter, File, UploadFile

from app.core.deps import CurrentUser
from app.schemas.common import UploadResponse

router = APIRouter(prefix="/uploads", tags=["uploads"])


@router.post("/images", response_model=UploadResponse, status_code=201)
async def upload_image(
    user_id: CurrentUser,
    file: Annotated[UploadFile, File()],
) -> UploadResponse:
    """上传单张图片，返回可公开访问的 URL。

    存储不可用时降级为本地磁盘——图片失败不应阻断写信主流程。
    """
    raise NotImplementedError
