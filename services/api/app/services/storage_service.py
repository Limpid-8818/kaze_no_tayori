"""图片存储（可降级）。

STORAGE_BACKEND=local 时写仓库根 uploads/（已 gitignore），s3 时走对象存储。
对象存储不可用时降级为本地磁盘——图片失败不应阻断写信主流程。
"""

from app.core.config import get_settings


async def save_image(data: bytes, filename: str) -> str:
    """压缩并保存图片，返回可公开访问的 URL。

    契约：
    1. 用 Pillow 压缩（明信片式，长边约 1600px，JPEG 质量 ~82）
    2. STORAGE_BACKEND=s3 且配置完整 → 上传对象存储
    3. 否则或上传失败 → 落盘 local_upload_dir，返回本地静态 URL
    """
    settings = get_settings()
    settings.local_upload_dir.mkdir(parents=True, exist_ok=True)
    raise NotImplementedError
