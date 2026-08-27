/// 就地发掘页的集中视图 mapper —— API 模型 → 摘要卡视图模型。
///
/// 映射只发生在这里（与 LetterView 同纪律）。距离字段服务端暂不下发
/// （匿名铁律），`distanceLabel` 留空——后端补齐后在 from() 一处接线。
library;

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
      poemLines: _poemLines(letter.poem),
      previewText: _preview(letter),
      placeLabel: letter.placeLabel,
      // distanceLabel：待后端 discover 响应补距离后在此接线
    );
  }

  static List<String> _poemLines(String? poem) => (poem ?? '')
      .trim()
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  /// 首个文字块的摘录；纯照片信用一句平实占位，不假装有文字。
  static String? _preview(LetterPublic letter) {
    for (final block in letter.blocks) {
      if (block.type == 'text' && (block.text?.trim().isNotEmpty ?? false)) {
        return block.text;
      }
    }
    if (letter.blocks.isNotEmpty) return '（一张照片）';
    return null;
  }
}
