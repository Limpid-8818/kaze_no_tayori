/// 就地发掘页的集中视图 mapper —— API 模型 → 摘要卡视图模型。
///
/// 映射只发生在这里（与 LetterView 同纪律）。距离由读者坐标 × 信的
/// 落点坐标（2026-08 起 discover 下发 lat/lon）在本文件算出。
library;

import '../../core/distance.dart';
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
    this.distanceLabel,
  });

  final String id;

  /// 俳句逐行；非空时卡片走短诗排版。
  final List<String> poemLines;

  /// 无诗时的正文预览摘录。
  final String? previewText;
  final String? placeLabel;

  /// 与读者的直线距离（「230m / 1.2km」）；坐标任一端缺席为 null。
  final String? distanceLabel;
  final String timeLabel;

  static DiscoverLetterView from(
    LetterPublic letter, {
    double? originLat,
    double? originLon,
  }) {
    return DiscoverLetterView(
      id: letter.id,
      timeLabel: relativeTimeLabel(letter.createdAt),
      poemLines: poemLinesOf(letter.poem),
      previewText: previewTextOf(letter),
      placeLabel: letter.placeLabel,
      distanceLabel: distanceLabelBetween(
        startLat: originLat,
        startLon: originLon,
        endLat: letter.lat,
        endLon: letter.lon,
      ),
    );
  }
}
