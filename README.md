# 风信 · Kaze no tayori（風の便り）

> 让作品先于作者抵达。
>
> 一个让旅行中陌生人的思绪匿名漂流、彼此接住的系统：信可以随机漂向远方，也可以埋在某地等后来者发掘。
> 不是社交网络，不是推荐平台，是「作品先于作者抵达」的慢媒介。

大工黑客松 S2 参赛项目 · 赛道「制造一点意外」。

---

## 这是什么

用户写下一段思绪（文字 + 可选图片 / 主题皮肤 / 音乐引用 / AI 短诗），然后选择：

- **📮 投递出去（Drift）** — 入随机漂流池，被任意陌生人抽到。
- **📍 留在这里（Stay）** — 锚定当前位置，后来者到了这里才能「就地发掘」。

读到信的人可以 **✦ 共鸣**（只计数，不是点赞）、收进**抄本**、或**回以一封信**——回信是一封独立的作品，不是私信，原作者只会收到一句轻悄的通知。

信件展示层永不携带作者信息，只留下 `地点 · 时间 · 天气`。

完整产品规格见 **[`docs/PRD.md`](docs/PRD.md)**（single source of truth），设计动机见 [`docs/设计叙事.md`](docs/设计叙事.md)。

---

## 60 秒上手

前置：Flutter 3.47+、[uv](https://docs.astral.sh/uv/)、GNU Make（git bash 下运行）。

```bash
cp .env.example .env      # 填入云数据库连接串与密钥（没有也能起后端）
make bootstrap            # 环境自检 + 装依赖 + 装 git hook
make api                  # 起后端 → http://localhost:8000/docs
make app                  # 起 App（Web；可用 APP_DEVICE 覆盖设备）
```

PostGIS 可用 `make db-up` 在本机启动，也可通过 `.env` 连接共享云实例。首次需要 `make migrate` 建表。

其余命令 `make help`。

---

## 仓库结构

```
docs/          产品与契约文档（PRD / 架构 / API 契约 / 开发环境）
services/api/  FastAPI 后端（PostgreSQL + PostGIS）
apps/app/      Flutter 应用（Android 主，Web 演示兜底）
apps/admin/    Flutter Web 运营控制台（P1，审核/信件/举报/反馈/种子信/统计）
packages/      Dart 包：natsu_no_tegami 设计系统
infra/         本地 PostGIS 与云端部署产物（docker-compose）
scripts/       仓库级脚本
```

技术栈：**Flutter** + **FastAPI** + **PostgreSQL/PostGIS**（就地发掘靠 `ST_DWithin`）。

---

## 开发约定

开发前请先读 **[`CLAUDE.md`](CLAUDE.md)** —— 它是本仓库的全局规则，其中第 2 节的 8 条红线（匿名铁律、不做社交度量、回信非私信……）不可违背。

- 提交：Conventional Commits + 中文描述，例 `feat: 就地发掘接口与 ST_DWithin 查询`
- 分支：trunk-based，直接提 `main`
- 质量：提交前 `make check`

---

## 命名说明

产品名是**风信 / Kaze no tayori**。`natsu_no_tegami`（夏の手紙）是当前视觉方向的代号，只用于设计系统包名，不是产品名。
