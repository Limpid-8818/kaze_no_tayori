# 风信 Kaze no tayori · 唯一任务入口
# 本机 make: D:\ProgramFiles\GnuWin32\bin\make (GNU Make 3.81)
# 在 git bash 下运行。所有目标都从仓库根执行。

SHELL := /bin/bash
API_DIR := services/api
APP_DIR := apps/app
UV := uv
API_BASE_URL ?= http://localhost:8000

.PHONY: help bootstrap hooks api app app-android gen revision migrate downgrade \
        seed check check-py check-dart check-db openapi sync-ds clean

# 终端输出一律 ASCII：Windows 控制台默认 GBK 代码页，中文会显示成乱码。
# 文档与注释用中文，echo 用英文。
help:
	@echo "Kaze no tayori - available targets"
	@echo "  make bootstrap    check env, install deps, install git hook"
	@echo "  make api          run backend (reload)"
	@echo "  make app          run app on web (edge; no Chrome on this machine)"
	@echo "  make app-android  run app on Android device"
	@echo "  make gen          Flutter codegen (freezed / riverpod)"
	@echo "  make revision m=\"...\"  Alembic autogenerate (REVIEW the output)"
	@echo "  make migrate      Alembic upgrade head"
	@echo "  make seed         load seed letters (cold start)"
	@echo "  make check        lint + typecheck + tests (skips DB tests)"
	@echo "  make check-db     run tests that need real PostGIS"
	@echo "  make openapi      export docs/openapi.json"
	@echo "  make sync-ds      sync design system from upstream"

bootstrap:
	@bash scripts/bootstrap.sh

hooks:
	@cp scripts/git-hooks/pre-commit .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "git pre-commit hook installed"

# ---------- 后端 ----------
api:
	cd $(API_DIR) && $(UV) run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

revision:
ifndef m
	$(error missing message: make revision m="init letter and account entities")
endif
	cd $(API_DIR) && $(UV) run alembic revision --autogenerate -m "$(m)"
	@echo ""
	@echo ">>> REVIEW the generated migration:"
	@echo "    1. spatial index NOT created twice (GeoAlchemy2 gotcha)"
	@echo "    2. CREATE EXTENSION postgis at the top of the first migration"

migrate:
	cd $(API_DIR) && $(UV) run alembic upgrade head

downgrade:
	cd $(API_DIR) && $(UV) run alembic downgrade -1

seed:
	cd $(API_DIR) && $(UV) run python scripts/seed_letters.py

check-db:
	cd $(API_DIR) && $(UV) run pytest -m db -v

openapi:
	cd $(API_DIR) && $(UV) run python scripts/export_openapi.py

# ---------- 前端 ----------
app:
	cd $(APP_DIR) && flutter run -d edge --dart-define=API_BASE_URL=$(API_BASE_URL)

app-android:
	cd $(APP_DIR) && flutter run --dart-define=API_BASE_URL=$(API_BASE_URL)

gen:
	cd $(APP_DIR) && dart run build_runner build --delete-conflicting-outputs

# ---------- 质量 ----------
check: check-py check-dart

check-py:
	cd $(API_DIR) && $(UV) run ruff format --check .
	cd $(API_DIR) && $(UV) run ruff check .
	cd $(API_DIR) && $(UV) run mypy app
	cd $(API_DIR) && $(UV) run pytest -m "not db"

check-dart:
	cd $(APP_DIR) && dart format --set-exit-if-changed lib test
	cd $(APP_DIR) && flutter analyze
	cd $(APP_DIR) && flutter test

# ---------- 杂项 ----------
sync-ds:
	@bash scripts/sync_design_system.sh

clean:
	cd $(APP_DIR) && flutter clean
	rm -rf $(API_DIR)/.pytest_cache $(API_DIR)/.mypy_cache $(API_DIR)/.ruff_cache
