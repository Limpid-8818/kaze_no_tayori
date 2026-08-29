import 'package:flutter/material.dart';

import '../../tokens/natsu_tokens.dart';
import '../natsu_typography.dart' show NatsuMetaLine;

/// 夏の手紙 v2 · 信纸 — 白纸浮于天空
///
/// paperWhite 底、近直角（radius 2）、letterResting 散影。纸面保持
/// 纯白——「光落在纸上」的信息传递已由环境天空（天气光联动）承担，
/// 纸自身不再画光。正在读的信是端正的（默认不倾斜；「不完美」属于
/// 桌面上散落的内容物，正在被阅读的东西应该被尊重）。
///
/// 结构（自上而下）：hw 正文 → meta 行（地点·日期·时段·天气，右对齐）→
/// 叙事计数句（左下，灰而退后）。
class LetterPaper extends StatelessWidget {
  const LetterPaper({
    super.key,
    required this.body,
    this.place,
    this.time,
    this.dayPeriod,
    this.weather,
    this.countLine,
    this.width = 560,
    this.padding = const EdgeInsets.fromLTRB(40, 44, 40, 32),
  });

  /// 手写正文（hwBody，LXGW WenKai 20/38）。
  final String body;

  /// 地点（meta 行第一项）
  final String? place;

  /// 时间
  final String? time;

  /// 时段单字（朝/昼/夕/夜）
  final String? dayPeriod;

  /// 天气
  final String? weather;

  /// 叙事计数句，如「已被 3 个陌生人拾起」——排成句子而非指标。
  final String? countLine;

  final double width;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final meta = [?place, ?time, ?dayPeriod, ?weather];

    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: NatsuColors.paperWhite,
        borderRadius: BorderRadius.circular(NatsuRadius.letter),
        border: NatsuBorders.hairline,
        boxShadow: NatsuShadows.letterResting,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(body, style: NatsuTypography.hwBody),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: NatsuSpacing.lg),
            Align(
              alignment: Alignment.centerRight,
              child: NatsuMetaLine(items: meta),
            ),
          ],
          if (countLine != null) ...[
            const SizedBox(height: NatsuSpacing.md),
            Text(
              countLine!,
              style: NatsuTypography.hwNote.copyWith(
                color: NatsuColors.inkFaint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
