/// 夏の手紙 设计系统 - 风信的令牌与组件库。
///
/// 源自上游独立仓库（见 COPY_IN.md），本包内**禁止手改**：
/// 一切改动在上游做，再 `make sync-ds` 同步。
///
/// 分层（上游纪律，详见各文件头注释）：
/// - `src/tokens/`：单一事实来源（色/字/距/影/动效/天气光/照片 mood），全部 const
/// - `src/components/`：UI 骨架（无阴影、严格对齐）+ `letters/` 信件内容物
library;

export 'src/components/components.dart';
export 'src/tokens/natsu_tokens.dart';
