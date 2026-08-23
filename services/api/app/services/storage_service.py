"""图片存储（可降级）。

本地写 uploads/（已 gitignore），s3 走七牛 Kodo S3 兼容接口。
对象存储不可用时降级为本地磁盘——图片失败不应阻断写信主流程。
"""

import asyncio
import logging
import uuid
from io import BytesIO

import boto3
from botocore.config import Config
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


def _normalize_endpoint(endpoint: str) -> str:
    """确保 endpoint 带协议头。"""
    endpoint = endpoint.strip()
    if not endpoint.startswith(("http://", "https://")):
        endpoint = f"https://{endpoint}"
    return endpoint


def _clean_endpoint_for_path_style(endpoint: str, bucket: str) -> str:
    """把 endpoint 里的 bucket 子域名去掉，让 path-style 寻址干净工作。

    七牛 S3 网关的 path-style：`https://s3.<region>.qiniucs.com/<bucket>/<key>`
    如果 endpoint 已写成 `https://<bucket>.s3.<region>.qiniucs.com`（virtual-hosted 形式），
    需要先剥掉子域名里的 bucket，否则 boto3 会把 bucket 重复拼进 key 路径。
    """
    endpoint = _normalize_endpoint(endpoint)
    scheme, _, host = endpoint.partition("://")
    bucket_prefix = f"{bucket}."
    if host.startswith(bucket_prefix):
        host = host[len(bucket_prefix) :]
    return f"{scheme}://{host}"


async def save_image(data: bytes, filename: str) -> str:
    """压缩并保存图片，返回可公开访问的 URL。

    契约：
    1. 用 Pillow 压缩（明信片式，长边约 1600px，JPEG 质量 ~82）
    2. STORAGE_BACKEND=s3 且配置完整 → 上传对象存储（七牛 Kodo S3 兼容接口）
    3. 否则或上传失败 → 落盘 local_upload_dir，返回本地静态 URL
    """
    settings = get_settings()
    compressed = await asyncio.to_thread(_compress, data)
    stored_name = f"{uuid.uuid4().hex}.jpg"  # 不信任客户端 filename，防穿越/冲突

    # ---------- S3 路径 ----------
    if settings.storage_backend == "s3" and settings.s3_access_key:
        try:

            def _do_upload() -> None:
                cleaned = _clean_endpoint_for_path_style(settings.s3_endpoint, settings.s3_bucket)
                client = boto3.client(
                    "s3",
                    endpoint_url=cleaned,
                    aws_access_key_id=settings.s3_access_key,
                    aws_secret_access_key=settings.s3_secret_key,
                    config=Config(
                        s3={"addressing_style": "path"},
                        signature_version="s3v4",
                    ),
                )
                client.put_object(
                    Bucket=settings.s3_bucket,
                    Key=stored_name,
                    Body=compressed,
                    ContentType="image/jpeg",
                )

            await asyncio.to_thread(_do_upload)

            # 拼接公开访问 URL
            if settings.s3_public_url:
                public_base = settings.s3_public_url.rstrip("/")
            else:
                # endpoint 已含 bucket 子域名（如 kazayori.s3.cn-east-1.qiniucs.com）
                public_base = _normalize_endpoint(settings.s3_endpoint)
            url = f"{public_base}/{stored_name}"
            logger.info("image uploaded to s3: %s (%d bytes)", stored_name, len(compressed))
            return url
        except Exception as exc:
            logger.warning("s3 upload failed, falling back to local: %s", exc)

    # ---------- 本地降级 ----------
    settings.local_upload_dir.mkdir(parents=True, exist_ok=True)
    (settings.local_upload_dir / stored_name).write_bytes(compressed)
    url = f"{settings.public_base_url}/uploads/{stored_name}"
    logger.info("image saved locally: %s (%d bytes)", stored_name, len(compressed))
    return url
