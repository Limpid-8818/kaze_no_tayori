"""storage_service：图片压缩落盘（无 DB）。"""

import io
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
from PIL import Image

from app.core.config import get_settings
from app.core.errors import InvalidImage
from app.services import storage_service


def _png_bytes(width: int, height: int) -> bytes:
    img = Image.new("RGB", (width, height), color=(120, 160, 200))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def _jpg_files(directory: Path) -> list[Path]:
    return [p for p in directory.iterdir() if p.suffix == ".jpg"]


@pytest.fixture
def upload_dir(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """强制本地后端，并隔离落盘目录。"""
    get_settings.cache_clear()
    settings = get_settings()
    settings.storage_backend = "local"
    settings.s3_access_key = ""

    monkeypatch.setattr(
        type(settings), "local_upload_dir", property(lambda self: tmp_path / "uploads")
    )
    return tmp_path / "uploads"


async def test_save_image_writes_and_returns_url(upload_dir: Path):  # type: ignore[no-untyped-def]
    url = await storage_service.save_image(_png_bytes(400, 300), "client-name.png")
    assert url.startswith("http")
    assert url.endswith(".jpg")
    files = _jpg_files(upload_dir)
    assert len(files) == 1
    # 落盘的是可解码的 JPEG
    with Image.open(files[0]) as img:
        assert img.format == "JPEG"


async def test_save_image_scales_long_edge(upload_dir: Path):  # type: ignore[no-untyped-def]
    url = await storage_service.save_image(_png_bytes(3200, 2400), "big.png")
    path = upload_dir / url.rsplit("/", 1)[-1]
    with Image.open(path) as img:
        assert max(img.size) <= 1600
        # 等比缩放
        assert img.size[0] / img.size[1] == pytest.approx(3200 / 2400)


async def test_save_image_rejects_garbage(upload_dir: Path):  # type: ignore[no-untyped-def]
    with pytest.raises(InvalidImage):
        await storage_service.save_image(b"not an image at all", "evil.png")


# ---------- S3 路径（mock，不碰真实七牛）----------

_S3_SETTINGS = {
    "storage_backend": "s3",
    "s3_access_key": "test_ak",
    "s3_secret_key": "test_sk",
    "s3_bucket": "kaze-test",
    "s3_endpoint": "s3.cn-east-1.qiniucs.com",
    "s3_public_url": "https://cdn.example.com",
}


@pytest.fixture
def s3_settings(monkeypatch: pytest.MonkeyPatch):
    """临时把 settings 切到 S3 模式（不落盘、不碰网络）。"""
    get_settings.cache_clear()
    s = get_settings()
    for k, v in _S3_SETTINGS.items():
        setattr(s, k, v)
    return s


async def test_save_image_s3_returns_cdn_url(s3_settings):  # type: ignore[no-untyped-def]
    mock_client = MagicMock()
    mock_client.put_object.return_value = None  # put_object 无返回值，靠异常判断成功

    with patch("app.services.storage_service.boto3.client", return_value=mock_client) as mocker:
        url = await storage_service.save_image(_png_bytes(400, 300), "x.png")

    # 确认 boto3 client 被正确构造（endpoint 无 bucket 前缀时不变）
    mocker.assert_called_once()
    call_kwargs = mocker.call_args.kwargs
    assert call_kwargs["endpoint_url"] == "https://s3.cn-east-1.qiniucs.com"
    assert call_kwargs["aws_access_key_id"] == "test_ak"
    # path-style + s3v4
    cfg = call_kwargs["config"]
    assert cfg.s3["addressing_style"] == "path"
    assert cfg.signature_version == "s3v4"

    # put_object 参数正确
    mock_client.put_object.assert_called_once()
    po_kwargs = mock_client.put_object.call_args.kwargs
    assert po_kwargs["Bucket"] == "kaze-test"
    assert po_kwargs["Key"].endswith(".jpg")
    assert po_kwargs["ContentType"] == "image/jpeg"
    assert isinstance(po_kwargs["Body"], bytes)

    # 返回 CDN URL
    assert url == "https://cdn.example.com/" + po_kwargs["Key"]


async def test_s3_endpoint_bucket_prefix_is_stripped(s3_settings):  # type: ignore[no-untyped-def]
    """如果 endpoint 带了 bucket 子域名（virtual-hosted 形式），应自动剥离。"""
    # 使用和 bucket 匹配的前缀来测试剥离逻辑
    s3_settings.s3_bucket = "kazayori"
    s3_settings.s3_endpoint = "kazayori.s3.cn-east-1.qiniucs.com"
    s3_settings.s3_public_url = ""

    mock_client = MagicMock()
    mock_client.put_object.return_value = None

    with patch("app.services.storage_service.boto3.client", return_value=mock_client) as mocker:
        url = await storage_service.save_image(_png_bytes(400, 300), "x.png")

    # boto3 收到的 endpoint_url 不带 bucket
    assert mocker.call_args.kwargs["endpoint_url"] == "https://s3.cn-east-1.qiniucs.com"
    # 返回的公开 URL 仍用原始 endpoint（含 bucket 子域名）
    key = mock_client.put_object.call_args.kwargs["Key"]
    assert url == "https://kazayori.s3.cn-east-1.qiniucs.com/" + key


async def test_save_image_s3_fallback_on_exception(s3_settings, upload_dir: Path):  # type: ignore[no-untyped-def]
    """S3 上传抛异常时降级为本地磁盘。"""
    with patch("app.services.storage_service.boto3.client", side_effect=RuntimeError("boom")):
        url = await storage_service.save_image(_png_bytes(400, 300), "fallback.png")

    # 降级：文件落在 upload_dir，URL 是本地 static 前缀
    assert "http://localhost:8000/uploads/" in url
    files = _jpg_files(upload_dir)
    assert len(files) == 1
