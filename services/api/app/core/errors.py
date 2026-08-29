"""统一错误体。

响应形状（见 docs/API_CONTRACT.md）：
    {"error": {"code": "letter_not_found", "message": "...", "detail": null}}
"""

from typing import Any

from asyncpg.exceptions import PostgresError
from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import SQLAlchemyError


class AppError(Exception):
    """业务异常基类。service 层抛它，router 不用手写 HTTPException。"""

    status_code: int = status.HTTP_400_BAD_REQUEST
    code: str = "bad_request"

    def __init__(self, message: str, detail: Any = None) -> None:
        super().__init__(message)
        self.message = message
        self.detail = detail


class NotFound(AppError):
    status_code = status.HTTP_404_NOT_FOUND
    code = "not_found"


class Unauthorized(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED
    code = "unauthorized"


class Forbidden(AppError):
    status_code = status.HTTP_403_FORBIDDEN
    code = "forbidden"


class FeatureDisabled(AppError):
    """可降级模块被关闭（PRD §8.3）。前端应据此降级，而非报错中断。"""

    status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    code = "feature_disabled"


class ServiceUnavailable(AppError):
    """依赖暂不可达（如共享云库连不上）。与 FeatureDisabled 区分：
    前者是「本该可用但挂了」，后者是「刻意关掉了」。"""

    status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    code = "service_unavailable"


class DriftPoolEmpty(NotFound):
    code = "drift_pool_empty"


class LetterNotFound(NotFound):
    """信不存在或未公开。不区分两者，避免泄漏存在性。"""

    code = "letter_not_found"


class LetterNotRetired(AppError):
    """未退场（taken_down / rejected 之外）的信不可「不再显示」，须先下架。"""

    status_code = status.HTTP_409_CONFLICT
    code = "letter_not_retired"


class InvalidImage(AppError):
    """上传的内容不是可解码的图片。"""

    status_code = 422
    code = "invalid_image"


class UnsupportedImageType(AppError):
    """上传的 content type 不在白名单。"""

    status_code = 422
    code = "unsupported_image_type"


class StayRequiresLocation(AppError):
    """stay 信缺坐标。"""

    status_code = status.HTTP_400_BAD_REQUEST
    code = "stay_requires_location"


def _body(code: str, message: str, detail: Any = None) -> dict[str, Any]:
    return {"error": {"code": code, "message": message, "detail": detail}}


def _unavailable(exc: Exception) -> JSONResponse:
    """共享云库连不上时统一降级为 503，而不是 500。

    数据库在比赛云服务器上，网络抖动/未配置都会走到这里。对客户端而言
    「稍后再试」比「服务器内部错误」准确得多。
    """
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content=_body(
            "service_unavailable",
            "数据库暂不可达，请稍后再试（配置见 docs/DEV_SETUP.md）",
            type(exc).__name__,
        ),
    )


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def _app_error(_: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content=_body(exc.code, exc.message, exc.detail),
        )

    @app.exception_handler(RequestValidationError)
    async def _validation_error(_: Request, exc: RequestValidationError) -> JSONResponse:
        return JSONResponse(
            status_code=422,
            content=_body("validation_error", "请求参数不合法", exc.errors()),
        )

    @app.exception_handler(SQLAlchemyError)
    async def _db_error(_: Request, exc: SQLAlchemyError) -> JSONResponse:
        return _unavailable(exc)

    # 连接建立阶段的 asyncpg 异常不经 SQLAlchemy 包装：
    # asyncpg.PostgresError / ConnectionDoesNotExistError 既不是 SQLAlchemyError
    # 也不是 OSError，只注册上面那个 handler 会漏成 500。
    @app.exception_handler(PostgresError)
    async def _pg_error(_: Request, exc: PostgresError) -> JSONResponse:
        return _unavailable(exc)

    @app.exception_handler(ConnectionError)
    async def _conn_error(_: Request, exc: ConnectionError) -> JSONResponse:
        return _unavailable(exc)
