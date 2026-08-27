/// 信件摘要的公共抽取口径 —— 摘要卡正文的唯一来源。
///
/// 发现列表（F4）与我的信（F6）共用同一套「俳句逐行 / 首个文字块
/// 摘录」规则：视图模型各自映射（集中 mapper 的纪律不变），但抽取
/// 在这里只实现一次，避免两处口径漂移。
library;

import '../data/models/letter.dart';

/// AI 短诗原文 → 逐行；null 或全空白一律回空列表（卡片走预览位）。
List<String> poemLinesOf(String? poem) => (poem ?? '')
    .trim()
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList();

/// 首个文字块的摘录；纯照片信用一句平实占位，不假装有文字。
String? previewTextOf(LetterPublic letter) {
  for (final block in letter.blocks) {
    if (block.type == 'text' && (block.text?.trim().isNotEmpty ?? false)) {
      return block.text;
    }
  }
  if (letter.blocks.isNotEmpty) return '（一张照片）';
  return null;
}
