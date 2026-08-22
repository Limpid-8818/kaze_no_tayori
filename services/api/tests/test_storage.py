"""storage_service：图片压缩落盘（无 DB）。"""

import io
from pathlib import Path

import pytest
from PIL import Image

from app.core.errors import InvalidImage
from app.services import storage_service


def _png_bytes(width: int, height: int) -> bytes:
    img = Image.new("RGB", (width, height), color=(120, 160, 200))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


@pytest.fixture
def upload_dir(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    from app.core.config import get_settings

    monkeypatch.setattr(
        type(get_settings()), "local_upload_dir", property(lambda self: tmp_path / "uploads")
    )
    return tmp_path / "uploads"


def _jpg_files(directory: Path) -> list[Path]:
    return [p for p in directory.iterdir() if p.suffix == ".jpg"]


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
