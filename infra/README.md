# Docker 环境

> 本地开发默认只启动 `db`，API 与 Flutter App 在宿主机运行，便于热重载和断点调试。完整 compose 栈用于部署验证，也是 PRD §11 DoD 要求的部署产物。

## 本机数据库

在仓库根目录运行：

```bash
make db-up
make migrate
make seed
make db-status
```

停止数据库但保留数据：

```bash
make db-stop
```

本机 compose 项目名固定为 `kaze-local`，数据库监听 `127.0.0.1:5432`，数据存放在 Docker volume `kaze-local_pgdata`。Apple Silicon 默认通过 Docker Desktop 运行官方 amd64 PostGIS 镜像。

## 完整服务栈

```bash
docker compose --env-file .env -f infra/docker-compose.yml up -d
docker compose --env-file .env -f infra/docker-compose.yml ps
curl localhost:8000/health
```

带对象存储（可选，默认用本地磁盘）：

```bash
docker compose --env-file .env -f infra/docker-compose.yml --profile s3 up -d
```

## 建表

迁移**不在容器启动时自动跑** —— 它需要人工审阅（GeoAlchemy2 的空间索引易重复）。

```bash
docker compose --env-file .env -f infra/docker-compose.yml exec api alembic upgrade head
docker compose --env-file .env -f infra/docker-compose.yml exec api python scripts/check_db.py
docker compose --env-file .env -f infra/docker-compose.yml exec api python scripts/seed_letters.py
```

## 组成

| 服务 | 说明 |
|---|---|
| `db` | `postgis/postgis:17-3.5`。首次启动自动执行 `init-db/01-postgis.sql` 装 extension |
| `api` | FastAPI，镜像见 `Dockerfile.api`，等 db healthcheck 通过才起 |
| `minio` | 对象存储，`--profile s3` 才启用 |

## 注意

- `POSTGRES_PASSWORD` 必填，compose 会在缺失时直接报错而不是用弱默认值。
- 容器内 `DB_SCHEMA=public`（部署环境不需要 per-developer schema 隔离，那是共享开发库才有的问题）。
- 云上如果只需要数据库、后端另行部署，`docker compose up -d db` 即可。
