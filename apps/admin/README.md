# 运营控制台（apps/admin）

> PRD 6.14，**P1**。形态已裁决（2026-08-29）：**Flutter Web**。
> ROADMAP **A0–A2 已完成**：后端管理端点、登录与角色权限、审核、信件、举报、反馈、统计和种子信管理均已落地。
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

## 冷启动脚本

运营台可管理种子信；需要批量初始化默认种子数据时仍可使用后端脚本：

```bash
make seed    # services/api/scripts/seed_letters.py
```

## 运行

```bash
make admin          # 使用平台默认 Web 设备
make admin APP_DEVICE=edge  # 也可显式指定设备
make admin-build    # flutter build web
```

账号：`cd services/api && uv run python scripts/create_admin.py --username ops --password '...'`

技术栈：Flutter + Riverpod + go_router；只复用 `packages/natsu_no_tegami` 的 token 层
（色板/字体），不复用叙事组件——管理端是中性密集工作台风格。
