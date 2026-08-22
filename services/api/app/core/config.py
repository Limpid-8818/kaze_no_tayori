"""应用配置。

所有配置从环境变量 / 仓库根 .env 读取。`FEATURE_*` 开关对应 PRD §8.3 的可降级模块：
任一模块关闭或失效，核心循环（写→漂→收→共鸣→再写）必须仍然跑通。
"""

from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict

# services/api/app/core/config.py → 仓库根
REPO_ROOT = Path(__file__).resolve().parents[4]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=REPO_ROOT / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # ---------- 应用 ----------
    app_env: Literal["dev", "prod", "test"] = "dev"
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    cors_origins: str = "http://localhost:*"
    # 拼图片公开 URL 的前缀（本地 StaticFiles 挂载在 /uploads）
    public_base_url: str = "http://localhost:8000"

    # ---------- 数据库 ----------
    # 运行时用 asyncpg，Alembic 迁移用 psycopg，两条指向同一个库
    database_url: str = "postgresql+asyncpg://user:pass@localhost:5432/kazenotayori"
    database_url_sync: str = "postgresql+psycopg://user:pass@localhost:5432/kazenotayori"
    # 共享云库靠 schema 隔离，每人一个（见 docs/DEV_SETUP.md §5）
    db_schema: str = "public"

    # ---------- 认证 ----------
    jwt_secret: str = "change-me"
    jwt_expire_days: int = 90
    jwt_algorithm: str = "HS256"

    # ---------- 产品参数 ----------
    discover_radius_m: int = 1000
    letter_max_chars: int = 800
    letter_max_images: int = 3

    # ---------- 可降级模块（PRD §8.3）----------
    feature_ai: bool = False
    openai_api_key: str = ""
    openai_base_url: str = ""
    openai_model: str = ""

    # 关闭或失败时新信一律 pending，绝不直接 public（PRD §8.2）
    feature_moderation: bool = False

    feature_weather: bool = False
    weather_api_key: str = ""

    feature_geocode: bool = False
    amap_key: str = ""

    # ---------- 图片存储 ----------
    storage_backend: Literal["local", "s3"] = "local"
    s3_endpoint: str = ""
    s3_bucket: str = ""
    s3_access_key: str = ""
    s3_secret_key: str = ""

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def local_upload_dir(self) -> Path:
        """STORAGE_BACKEND=local 时的落盘目录（已在 .gitignore 中）。"""
        return REPO_ROOT / "uploads"


@lru_cache
def get_settings() -> Settings:
    return Settings()
