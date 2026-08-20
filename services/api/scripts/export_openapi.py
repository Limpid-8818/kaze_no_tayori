"""导出 OpenAPI 到 docs/openapi.json。

用法：make openapi

意义：契约漂移时 git diff 立刻可见（docs/API_CONTRACT.md 是人读的契约，
这份 JSON 是机器可比对的快照）。改了 endpoint 就该跑一次。
"""

import json
import sys

from app.core.config import REPO_ROOT
from app.main import app

OUT = REPO_ROOT / "docs" / "openapi.json"


def main() -> int:
    schema = app.openapi()
    OUT.write_text(
        json.dumps(schema, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"[ok] wrote {OUT.relative_to(REPO_ROOT)} ({len(schema['paths'])} paths)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
