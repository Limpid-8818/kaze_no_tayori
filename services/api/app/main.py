"""FastAPI 应用入口。

启动：make api（等价于 uv run uvicorn app.main:app --reload）
文档：http://localhost:8000/docs
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.v1 import health
from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.errors import register_error_handlers


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title="风信 Kaze no tayori API",
        description=(
            "匿名漂流信系统。信可随机漂向远方（drift），也可埋在某地等后来者发掘（stay）。\n\n"
            "**匿名铁律**：一切信件响应使用 LetterPublic，不含任何作者标识。"
        ),
        version="0.1.0",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=".*" if settings.app_env == "dev" else None,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    register_error_handlers(app)

    app.include_router(health.router)
    app.include_router(api_router)

    # 本地图片静态服务（STORAGE_BACKEND=local 时 storage_service 落盘于此）
    settings.local_upload_dir.mkdir(parents=True, exist_ok=True)
    app.mount("/uploads", StaticFiles(directory=settings.local_upload_dir), name="uploads")

    return app


app = create_app()
