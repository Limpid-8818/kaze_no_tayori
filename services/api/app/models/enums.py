"""领域枚举。"""

from enum import StrEnum


class DeliveryMode(StrEnum):
    """投递方式（PRD 6.1：必选其一，两者都是一等公民）。"""

    STAY = "stay"  # 留在这里：锚定位置，后来者就地发掘
    DRIFT = "drift"  # 投递出去：入随机漂流池


class LetterStatus(StrEnum):
    """信件状态（见 docs/ARCHITECTURE.md §3 状态机）。

    只有 PUBLIC 参与漂流抽取与就地发掘。
    机审失效时默认停在 PENDING —— 降级方向永远更保守（PRD §8.2）。
    """

    PENDING = "pending"
    PUBLIC = "public"
    REJECTED = "rejected"
    TAKEN_DOWN = "taken_down"


class NotificationType(StrEnum):
    """通知类型。P0 只有回信告知（PRD 6.5），且它不是私信。"""

    REPLY = "reply"
