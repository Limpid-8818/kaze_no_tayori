"""全部 ORM 模型。

Alembic 的 target_metadata 依赖本模块导入所有模型——**新增模型必须在此登记**，
否则 autogenerate 不会发现它。
"""

from app.models.base import Base
from app.models.catalog import Theme, ThoughtTag
from app.models.enums import (
    DeliveryMode,
    FeedbackCategory,
    FeedbackStatus,
    LetterStatus,
    NotificationType,
)
from app.models.feedback import Feedback
from app.models.letter import Letter
from app.models.letter_read import LetterRead
from app.models.notification import Notification
from app.models.report import AdminAccount, Report
from app.models.resonance import ResonanceLog
from app.models.scripbook import ScripbookEntry
from app.models.user import User

__all__ = [
    "AdminAccount",
    "Base",
    "DeliveryMode",
    "Feedback",
    "FeedbackCategory",
    "FeedbackStatus",
    "Letter",
    "LetterRead",
    "LetterStatus",
    "Notification",
    "NotificationType",
    "Report",
    "ResonanceLog",
    "ScripbookEntry",
    "Theme",
    "ThoughtTag",
    "User",
]
