"""数据库连通性自检。

用法：cd services/api && uv run python scripts/check_db.py

输出一律英文：Windows 控制台默认 GBK 代码页，中文会乱码。
"""

import asyncio
import sys

from sqlalchemy import text

from app.core.config import get_settings
from app.core.db import SessionLocal


async def main() -> int:
    settings = get_settings()
    print("=== Kaze no tayori - database check ===")
    print(f"  configured schema : {settings.db_schema}")

    try:
        async with SessionLocal() as session:
            version = (await session.execute(text("SELECT version()"))).scalar_one()
            print(f"  postgres          : {str(version).split(',')[0]}")

            postgis = (await session.execute(text("SELECT PostGIS_version()"))).scalar_one()
            print(f"  postgis           : {postgis}")

            schema = (await session.execute(text("SELECT current_schema()"))).scalar_one()
            print(f"  current_schema    : {schema}")

            tables = (
                (
                    await session.execute(
                        text(
                            "SELECT table_name FROM information_schema.tables "
                            "WHERE table_schema = :s ORDER BY table_name"
                        ),
                        {"s": settings.db_schema},
                    )
                )
                .scalars()
                .all()
            )
            print(f"  tables ({len(tables)})       : {', '.join(tables) if tables else '(none)'}")

            # 确认就地发掘依赖的 GiST 索引存在
            idx = (
                (
                    await session.execute(
                        text(
                            "SELECT indexname FROM pg_indexes "
                            "WHERE schemaname = :s AND tablename = 'letters'"
                        ),
                        {"s": settings.db_schema},
                    )
                )
                .scalars()
                .all()
            )
            if idx:
                print(f"  letters indexes   : {', '.join(idx)}")
                has_gist = any("location" in i or "geog" in i for i in idx)
                gist_state = "found" if has_gist else "NOT FOUND - run make migrate"
                print(f"  spatial index     : {gist_state}")
            else:
                print("  letters indexes   : (table missing - run make migrate)")

    except Exception as exc:
        print("")
        print(f"[x] connection failed: {type(exc).__name__}: {exc}")
        print("    check DATABASE_URL in the repo-root .env (see docs/DEV_SETUP.md)")
        return 1

    print("")
    print("[ok] database reachable.")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
