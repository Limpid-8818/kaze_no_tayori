#!/usr/bin/env bash
# 风信 · 一次性环境自检 + 装依赖。幂等，可重复跑。
# 注意：终端输出一律 ASCII —— Windows 控制台默认 GBK 代码页，中文会乱码。
set -uo pipefail
cd "$(dirname "$0")/.."

echo "=== Kaze no tayori - environment check ==="
echo ""

missing=0
need() {
  local name="$1" cmd="$2" hint="$3"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "  [ok] %-8s %s\n" "$name" "$("$cmd" --version 2>&1 | head -1)"
  else
    printf "  [--] %-8s NOT FOUND - %s\n" "$name" "$hint"
    missing=1
  fi
}

need flutter flutter "https://flutter.dev/setup"
need dart    dart    "ships with Flutter"
need uv      uv      "https://docs.astral.sh/uv/getting-started/installation/"
need git     git     "https://git-scm.com/"

echo ""
echo "=== known environment facts ==="
echo "  - web device is selected by make app (override with APP_DEVICE=...)"
echo "  - local PostGIS is available through Docker: make db-up"
echo "  - remote PostgreSQL is also supported through DATABASE_URL"
echo ""

if [ "$missing" -ne 0 ]; then
  echo "Missing required tools. Install them first."
  exit 1
fi

# ---------- .env ----------
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example - fill in DB connection string and keys."
else
  echo ".env already exists, skipping."
fi

# ---------- 后端依赖 ----------
if [ -f services/api/pyproject.toml ]; then
  echo ""
  echo "=== installing backend deps (uv sync) ==="
  ( cd services/api && uv sync --frozen ) || { echo "uv sync failed"; exit 1; }
fi

# ---------- 前端依赖 ----------
if [ -f apps/app/pubspec.yaml ]; then
  echo ""
  echo "=== installing frontend deps (flutter pub get) ==="
  ( cd apps/app && flutter pub get ) || { echo "flutter pub get failed"; exit 1; }
fi

# ---------- git hook ----------
if [ -d .git ] && [ -f scripts/git-hooks/pre-commit ]; then
  cp scripts/git-hooks/pre-commit .git/hooks/pre-commit
  chmod +x .git/hooks/pre-commit
  echo ""
  echo "git pre-commit hook installed."
fi

echo ""
echo "=== done. local DB: make db-up / make migrate / make seed  (make help for all targets) ==="
