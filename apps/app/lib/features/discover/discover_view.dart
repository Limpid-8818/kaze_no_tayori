/// 就地发掘页的集中视图 mapper —— API 模型 → 摘要卡视图模型。
///
/// 映射只发生在这里（与 LetterView 同纪律）。距离字段服务端暂不下发
/// （匿名铁律），`distanceLabel` 留空——后端补齐后在 from() 一处接线。
library;

import '../../core/letter_preview.dart';
import '../../core/relative_time.dart';
import '../../data/models/letter.dart';

/// 一张摘要卡的视图模型。
class DiscoverLetterView {
  const DiscoverLetterView({
    required this.id,
    required this.timeLabel,
    this.poemLines = const [],
    this.previewText,
    this.placeLabel,
  });

  final String id;

  /// 俳句逐行；非空时卡片走短诗排版。
  final List<String> poemLines;

  /// 无诗时的正文预览摘录。
  final String? previewText;
  final String? placeLabel;
  final String timeLabel;

  static DiscoverLetterView from(LetterPublic letter) {
    return DiscoverLetterView(
      id: letter.id,
      timeLabel: relativeTimeLabel(letter.createdAt),
      poemLines: poemLinesOf(letter.poem),
      previewText: previewTextOf(letter),
      placeLabel: letter.placeLabel,
      // distanceLabel：待后端 discover 响应补距离后在此接线
    );
  }
}
