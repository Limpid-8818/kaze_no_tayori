# 部署（云服务器）

> **本地开发不用这里的东西。** 本机没装 Docker，开发直连云端 PostGIS，见 `docs/DEV_SETUP.md`。
> 本目录是 PRD §11 DoD 要求的部署产物。

## 起服务

```bash
cd infra
# .env 在仓库根，compose 会读它；另需 POSTGRES_PASSWORD
POSTGRES_PASSWORD=... docker compose up -d
docker compose ps
curl localhost:8000/health
```

带对象存储（可选，默认用本地磁盘）：

```bash
POSTGRES_PASSWORD=... S3_SECRET_KEY=... docker compose --profile s3 up -d
```

## 建表

迁移**不在容器启动时自动跑** —— 它需要人工审阅（GeoAlchemy2 的空间索引易重复）。

```bash
docker compose exec api alembic upgrade head
docker compose exec api python scripts/check_db.py
docker compose exec api python scripts/seed_letters.py   # 冷启动种子信
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
