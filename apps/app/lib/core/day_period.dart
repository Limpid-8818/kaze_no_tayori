/// 时段推导 — 首页问候语与环境行「地点 · 时段 · 天气」的客户端一环。
///
/// 纯函数、无 UI 依赖：地点/天气由后端（逆地理/天气服务，当前为可降级桩）
/// 供给，时段永远可从本地时钟推出 —— 降级纪律的「恒显示」部分。
library;

/// 一天四段。（不叫 DayPeriod — 与 material 的 TimeOfDay 同域枚举撞名。）
enum KazeDayPeriod { morning, noon, evening, night }

/// [now] 所处时段：5–11 点朝、11–17 点昼、17–22 点夕、其余夜。
KazeDayPeriod dayPeriodOf(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 11) return KazeDayPeriod.morning;
  if (h >= 11 && h < 17) return KazeDayPeriod.noon;
  if (h >= 17 && h < 22) return KazeDayPeriod.evening;
  return KazeDayPeriod.night;
}

/// 问候语 — 首页标题区。
String greetingFor(KazeDayPeriod period) => switch (period) {
  KazeDayPeriod.morning => '早上好',
  KazeDayPeriod.noon => '中午好',
  KazeDayPeriod.evening => '晚上好',
  KazeDayPeriod.night => '夜深了',
};

/// 时段单字 — 环境行芯片（朝/昼/夕/夜）。
String dayPeriodLabel(KazeDayPeriod period) => switch (period) {
  KazeDayPeriod.morning => '朝',
  KazeDayPeriod.noon => '昼',
  KazeDayPeriod.evening => '夕',
  KazeDayPeriod.night => '夜',
};
