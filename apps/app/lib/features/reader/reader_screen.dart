import 'package:flutter/material.dart';

import '../../app/widgets/placeholder_screen.dart';

/// 阅读一封信：地点·时间·天气 + 正文 + 图 + 短诗 + 音乐引用 + 叙事计数。
///
/// **不渲染任何作者信息** —— 服务端也不会给。
/// 页内动作：✦ 共鸣、收进抄本、导出为图片、回以一封信。
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({required this.letterId, super.key});

  final String letterId;

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '读一封信',
      intent: '只有地点·时间·天气，没有作者。可以 ✦ 共鸣、收进抄本、导出为图片，或回以一封信。',
      prdRef: '6.3 / 6.6',
    );
  }
}
