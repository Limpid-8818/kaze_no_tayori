import 'package:flutter/material.dart';

import '../tokens/natsu_tokens.dart';

/// 夏の手紙 v2 · 引用块 — 铅字回归之处
///
/// 本系统的「引用」承载两个语义（同一视觉范式）：
/// 1. 回信链——「一封信引用另一封信」的一行式引用（非聊天气泡）；
/// 2. 音乐引用——『此刻我循环着《专辑》的《歌》——「歌词一句」』。
///
/// v2 视觉：暖封底 + 纸浮起轻影；珊瑚左线与引号（邮戳/旅行的颜色）；
/// 正文用 quoteSerif——系统中唯一的衬线样式，纸上的铅字 vs 手写的对比
/// 本就是书信文化的一部分。
class NatsuQuote extends StatelessWidget {
  const NatsuQuote({
    super.key,
    required this.text,
    this.source,
    this.kind = NatsuQuoteKind.letter,
  });

  /// 引用正文（一句）。
  final String text;

  /// 引用来源：回信链为「原信落款（地点·时间）」，音乐为《专辑》·《歌曲》。
  final String? source;

  final NatsuQuoteKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NatsuSpacing.lg,
        vertical: NatsuSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: NatsuColors.envelope,
        border: Border(
          left: BorderSide(color: NatsuColors.coralStamp, width: 2),
        ),
        boxShadow: NatsuShadows.paperResting,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '「',
                style: NatsuTypography.hwAddress.copyWith(
                  color: NatsuColors.coralStamp,
                  fontSize: 20,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: NatsuSpacing.sm),
              Expanded(
                child: Text(text, style: NatsuTypography.quoteSerif),
              ),
            ],
          ),
          if (source != null) ...[
            const SizedBox(height: NatsuSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: NatsuSpacing.xl),
              child: Text(
                kind == NatsuQuoteKind.music ? '♪ $source' : '— $source',
                style: NatsuTypography.meta,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum NatsuQuoteKind { letter, music }
