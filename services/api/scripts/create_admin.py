"""管理端账号创建（AdminAccount，PRD 6.14 首次启用）。

用法：cd services/api && uv run python scripts/create_admin.py \
    --username ops --password '...' --role admin

同名账号已存在时更新密码与角色（upsert），不重复建行。
输出一律英文：Windows 控制台默认 GBK 代码页，中文会乱码。
"""

import argparse
import asyncio
import sys

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.core.db import SessionLocal
from app.core.security import hash_password
from app.models.report import AdminAccount


async def main() -> int:
    parser = argparse.ArgumentParser(description="Create or update an admin account")
    parser.add_argument("--username", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument("--role", default="admin", choices=["admin", "viewer"])
    args = parser.parse_args()

    if len(args.password) < 8:
        print("[x] password must be at least 8 characters")
        return 1

    password_hash = hash_password(args.password)
    try:
        async with SessionLocal() as session:
            stmt = (
                pg_insert(AdminAccount)
                .values(username=args.username, password_hash=password_hash, role=args.role)
                .on_conflict_do_update(
                    index_elements=[AdminAccount.username],
                    set_={"password_hash": password_hash, "role": args.role},
                )
            )
            await session.execute(stmt)
            await session.commit()
            row = (
                await session.execute(
                    select(AdminAccount.username, AdminAccount.role).where(
                        AdminAccount.username == args.username
                    )
                )
            ).one()
            print(f"[ok] admin account upserted: {row.username} (role={row.role})")
            return 0
    except Exception as exc:
        print(f"[x] failed: {type(exc).__name__}: {exc}")
        print("    check DATABASE_URL in the repo-root .env (see docs/DEV_SETUP.md)")
        return 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
