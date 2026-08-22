"""图片存储（可降级）。

STORAGE_BACKEND=local 时写仓库根 uploads/（已 gitignore），s3 时走对象存储。
对象存储不可用时降级为本地磁盘——图片失败不应阻断写信主流程。
"""

import asyncio
import logging
import uuid
from io import BytesIO

from PIL import Image, ImageOps, UnidentifiedImageError

from app.core.config import get_settings
from app.core.errors import InvalidImage

logger = logging.getLogger(__name__)

_MAX_EDGE = 1600
_JPEG_QUALITY = 82


def _compress(data: bytes) -> bytes:
    """明信片式压缩：EXIF 转正 → 长边 ≤1600 → JPEG q82。"""
    try:
        img: Image.Image = Image.open(BytesIO(data))
        img = ImageOps.exif_transpose(img)
    except UnidentifiedImageError as exc:
        raise InvalidImage("无法识别的图片格式") from exc
    if img.width > _MAX_EDGE or img.height > _MAX_EDGE:
        img.thumbnail((_MAX_EDGE, _MAX_EDGE), Image.Resampling.LANCZOS)
    if img.mode != "RGB":
        img = img.convert("RGB")
    buf = BytesIO()
    img.save(buf, format="JPEG", quality=_JPEG_QUALITY)
    return buf.getvalue()


async def save_image(data: bytes, filename: str) -> str:
    """压缩并保存图片，返回可公开访问的 URL。

    契约：
    1. 用 Pillow 压缩（明信片式，长边约 1600px，JPEG 质量 ~82）
    2. STORAGE_BACKEND=s3 且配置完整 → 上传对象存储（B7 接入，当前仅 local）
    3. 否则或上传失败 → 落盘 local_upload_dir，返回本地静态 URL
    """
    settings = get_settings()
    settings.local_upload_dir.mkdir(parents=True, exist_ok=True)

    compressed = await asyncio.to_thread(_compress, data)
    stored_name = f"{uuid.uuid4().hex}.jpg"  # 不信任客户端 filename，防穿越/冲突
    (settings.local_upload_dir / stored_name).write_bytes(compressed)
    url = f"{settings.public_base_url}/uploads/{stored_name}"
    logger.info("image saved: %s (%d -> %d bytes)", stored_name, len(data), len(compressed))
    return url
