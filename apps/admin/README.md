# 运营控制台（apps/admin）

> PRD 6.14，**P1**。形态已裁决（2026-08-29）：**Flutter Web**。
> 本目录当前仍无代码，实施随 ROADMAP **A 系列**（A0 后端补齐 → A1 骨架+审核 → A2 举报/反馈/种子信）启动。
> **设计事实来源：[docs/ADMIN_CONSOLE.md](../../docs/ADMIN_CONSOLE.md)**；契约见 [docs/API_CONTRACT.md](../../docs/API_CONTRACT.md) §3「管理端」。

## v1 范围

- 审核队列：pending → public / rejected（两段式确认）
- 信件管理：下架（→ taken_down）/ 恢复 / 赦免
- 举报处理：下架并 actioned / dismissed（reports 表迁移随 A0）
- 反馈管理：复用现有 `/v1/admin/feedbacks` 接口
- 统计概览：状态分布 / 池健康 / 待办角标
- 种子信件管理：列表 / 新建 / 编辑 / 下架恢复（owner=NULL，public 直接入池）

账号与匿名用户体系完全隔离（`admin_accounts` 表，`scripts/create_admin.py` 创建；
`admin` 可写、`viewer` 只读），不向访客暴露作者。

## 实施前怎么办

冷启动与审核放行仍由后端脚本承担：

```bash
make seed    # services/api/scripts/seed_letters.py
```

## 将来怎么跑（已随 A1/A2 落地）

```bash
make admin          # flutter run -d edge（Windows 无 Chrome，见根 CLAUDE.md）
make admin-build    # flutter build web
```

账号：`cd services/api && uv run python scripts/create_admin.py --username ops --password '...'`

技术栈：Flutter + Riverpod + go_router；只复用 `packages/natsu_no_tegami` 的 token 层
（色板/字体），不复用叙事组件——管理端是中性密集工作台风格。
