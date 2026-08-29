# 风信 Kaze no tayori · 唯一任务入口
# GNU Make 3.81+。所有目标都从仓库根执行。

SHELL := /bin/bash
API_DIR := services/api
APP_DIR := apps/app
ADMIN_DIR := apps/admin
DESIGN_SYSTEM_DIR := packages/natsu_no_tegami
UV := uv
UV_RUN := $(UV) run --frozen
API_BASE_URL ?= http://localhost:8000
COMPOSE := docker compose -p kaze-local --env-file .env -f infra/docker-compose.yml
ifeq ($(OS),Windows_NT)
APP_DEVICE ?= edge
else
APP_DEVICE ?= chrome
endif

.PHONY: help bootstrap hooks db-up db-stop db-status api app app-android app-android-emulator app-android-emulator-mock app-ios admin admin-build gen gen-watch \
        revision migrate downgrade seed check check-py check-dart check-db openapi sync-ds clean

# 终端输出一律 ASCII：Windows 控制台默认 GBK 代码页，中文会显示成乱码。
# 文档与注释用中文，echo 用英文。
help:
	@echo "Kaze no tayori - available targets"
	@echo "  make bootstrap    check env, install deps, install git hook"
	@echo "  make db-up        start local PostGIS with Docker"
	@echo "  make db-stop      stop local PostGIS (keep data volume)"
	@echo "  make db-status    show local PostGIS status"
	@echo "  make api          run backend (reload)"
	@echo "  make app          run app on web (APP_DEVICE=$(APP_DEVICE))"
	@echo "  make app-android  run app on Android device"
	@echo "  make app-android-emulator  run app on Android Emulator (10.0.2.2)"
	@echo "  make app-android-emulator-mock  run app on Emulator with mock API (no backend)"
	@echo "  make app-ios IOS_DEVICE=<id>  run app on iOS device/simulator"
	@echo "  make admin         run ops console on web (APP_DEVICE, default edge)"
	@echo "  make admin-build   build ops console (flutter build web)"
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

# ---------- 本地数据库 ----------
db-up:
	$(COMPOSE) up -d db

db-stop:
	$(COMPOSE) stop db

db-status:
	$(COMPOSE) ps db

hooks:
	@cp scripts/git-hooks/pre-commit .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "git pre-commit hook installed"

# ---------- 后端 ----------
api:
	cd $(API_DIR) && $(UV_RUN) uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

revision:
ifndef m
	$(error missing message: make revision m="init letter and account entities")
endif
	cd $(API_DIR) && $(UV_RUN) alembic revision --autogenerate -m "$(m)"
	@echo ""
	@echo ">>> REVIEW the generated migration:"
	@echo "    1. spatial index NOT created twice (GeoAlchemy2 gotcha)"
	@echo "    2. CREATE EXTENSION postgis at the top of the first migration"

migrate:
	cd $(API_DIR) && $(UV_RUN) alembic upgrade head

downgrade:
	cd $(API_DIR) && $(UV_RUN) alembic downgrade -1

seed:
	cd $(API_DIR) && $(UV_RUN) python scripts/seed_letters.py

check-db:
	cd $(API_DIR) && $(UV_RUN) pytest -m db -v

openapi:
	cd $(API_DIR) && $(UV_RUN) python scripts/export_openapi.py

# ---------- 前端 ----------
app:
	cd $(APP_DIR) && flutter run -d $(APP_DEVICE) --dart-define=API_BASE_URL=$(API_BASE_URL)

app-android:
	cd $(APP_DIR) && flutter run --dart-define=API_BASE_URL=$(API_BASE_URL)

# Android Emulator 专用：10.0.2.2 是 Emulator 访问宿主机 localhost 的别名。
# 物理真机仍用 make app-android API_BASE_URL=http://<LAN_IP>:8000。
app-android-emulator:
	cd $(APP_DIR) && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Emulator + 运行时 mock（USE_MOCK_API）：全部网络走 MockApiAdapter，
# 不需要本地后端也能走通写信闭环。
app-android-emulator-mock:
	cd $(APP_DIR) && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 --dart-define=USE_MOCK_API=true

app-ios:
ifndef IOS_DEVICE
	$(error missing iOS device id: run "flutter devices", then make app-ios IOS_DEVICE=<id>)
endif
	cd $(APP_DIR) && flutter run -d "$(IOS_DEVICE)" --dart-define=API_BASE_URL=$(API_BASE_URL)

# ---------- 运营控制台（apps/admin，Flutter Web）----------
admin:
	cd $(ADMIN_DIR) && flutter run -d $(APP_DEVICE) --dart-define=API_BASE_URL=$(API_BASE_URL)

admin-build:
	cd $(ADMIN_DIR) && flutter build web --dart-define=API_BASE_URL=$(API_BASE_URL)

# build_runner 2.x 已移除 --delete-conflicting-outputs（传了只会警告）
gen:
	cd $(APP_DIR) && dart run build_runner build

gen-watch:
	cd $(APP_DIR) && dart run build_runner watch

# ---------- 质量 ----------
check: check-py check-dart

check-py:
	cd $(API_DIR) && $(UV_RUN) ruff format --check .
	cd $(API_DIR) && $(UV_RUN) ruff check .
	cd $(API_DIR) && $(UV_RUN) mypy app
	cd $(API_DIR) && $(UV_RUN) pytest -m "not db"

check-dart:
	cd $(APP_DIR) && dart format --set-exit-if-changed lib test
	cd $(APP_DIR) && flutter analyze
	cd $(APP_DIR) && flutter test
	cd $(ADMIN_DIR) && dart format --set-exit-if-changed lib test
	cd $(ADMIN_DIR) && flutter analyze
	cd $(ADMIN_DIR) && flutter test
	cd $(DESIGN_SYSTEM_DIR) && dart format --set-exit-if-changed lib test
	cd $(DESIGN_SYSTEM_DIR) && flutter analyze
	cd $(DESIGN_SYSTEM_DIR) && flutter test test/tokens test/components

# ---------- 杂项 ----------
sync-ds:
	@bash scripts/sync_design_system.sh

clean:
	cd $(APP_DIR) && flutter clean
	rm -rf $(API_DIR)/.pytest_cache $(API_DIR)/.mypy_cache $(API_DIR)/.ruff_cache
