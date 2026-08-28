/// 相对时间标签 —— 「刚刚 / N分钟前 / N小时前 / N天前」，超过一周回退日期。
///
/// 发现列表与回信列表共用同一口径；上限不是问题（列表只展示最近内容）。
library;

String relativeTimeLabel(DateTime created) {
  final diff = DateTime.now().difference(created);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
  if (diff.inDays < 1) return '${diff.inHours}小时前';
  if (diff.inDays < 7) return '${diff.inDays}天前';
  return dayLabel(created);
}

/// 精确到日的日期标签「M月D日」。
String dayLabel(DateTime date) => '${date.month}月${date.day}日';
