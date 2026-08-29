"""v1 路由汇总。

新增 router 时在此登记。注意路径前缀不要与已有冲突。
"""

from fastapi import APIRouter

from app.api.v1 import (
    admin,
    ai,
    auth,
    catalog,
    discover,
    drift,
    feedback,
    geo,
    letters,
    me,
    replies,
    resonance,
    uploads,
    weather,
)

api_router = APIRouter(prefix="/v1")

api_router.include_router(auth.router)
api_router.include_router(letters.router)
api_router.include_router(drift.router)
api_router.include_router(discover.router)
api_router.include_router(replies.router)
api_router.include_router(resonance.router)
api_router.include_router(me.router)
api_router.include_router(ai.router)
api_router.include_router(uploads.router)
api_router.include_router(catalog.router)
api_router.include_router(weather.router)
api_router.include_router(geo.router)
api_router.include_router(feedback.router)
api_router.include_router(admin.router)
