import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../tokens/natsu_tokens.dart';
import '../natsu_typography.dart' show NatsuMetaLine;
import 'letter_block.dart';
import 'photo_card.dart';

/// 夏の手紙 v2 · 阅读视图 — 图文交替流，信被展开读的样子
///
/// 与 LetterPaper（桌上摊着的信，无图、桌面宽）职责分离：这里是
/// 「开信之后读到的」——段落流中夹着照片（PhotoBlock），像真实信里
/// 夹照片。照片宽 `width × 0.72` 居中（夹进信里的照片比纸窄，
/// 撑满会变杂志排版），带半量种子倾斜（信被读时端正——纸是被尊重
/// 的，但夹着的照片保留一点歪，它是被夹进去的实物）。
///
/// [photoResolver] 把 PhotoBlock.imageRef（字符串）解析为
/// ImageProvider——lib 层与图片来源解耦，App 注入自己的资产策略。
class LetterReading extends StatelessWidget {
  const LetterReading({
    super.key,
    required this.blocks,
    required this.photoResolver,
    this.seedId,
    this.width = 560,
    this.place,
    this.time,
    this.weather,
    this.signature,
  });

  /// 图文交替流（validateLetterFlow 校验过的一封信）
  final List<LetterBlock> blocks;

  /// 图片引用 → ImageProvider（App 的资产策略）
  final ImageProvider Function(String ref) photoResolver;

  /// 照片块倾斜/布局种子；null = 照片也完全端正（最阅读态）
  final String? seedId;

  final double width;

  /// meta 行（地点·时间·天气，底部右对齐）
  final String? place;
  final String? time;
  final String? weather;

  /// 信尾署名 → 右下横排（hwAddress 手写；可空）
  final String? signature;

  @override
  Widget build(BuildContext context) {
    final meta = [?place, ?time, ?weather];

    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(40, 44, 40, 32),
      decoration: BoxDecoration(
        color: NatsuColors.paperWhite,
        borderRadius: BorderRadius.circular(NatsuRadius.letter),
        border: NatsuBorders.hairline,
        boxShadow: NatsuShadows.letterResting,
      ),
      // 纸面保持纯白——光的信息传递由环境天空（天气光联动）承担
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, block) in blocks.indexed) ...[
            if (i > 0) const SizedBox(height: NatsuSpacing.lg),
            switch (block) {
              TextBlock(:final text) => Text(
                text,
                style: NatsuTypography.hwBody,
              ),
              PhotoBlock(:final imageRef, :final mood, :final note) =>
                _PhotoInLetter(
                  image: photoResolver(imageRef),
                  mood: mood,
                  note: note,
                  photoSeed: seedId == null ? null : '$seedId/photo/$i',
                  width: width * 0.72,
                ),
            },
          ],
          if (signature != null) ...[
            const SizedBox(height: NatsuSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: Text(signature!, style: NatsuTypography.hwAddress),
            ),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: NatsuSpacing.lg),
            Align(
              alignment: Alignment.centerRight,
              child: NatsuMetaLine(items: meta),
            ),
          ],
        ],
      ),
    );
  }
}

/// 流中照片块 — 居中、半量倾斜（种子派生 × 0.5）、带手记
class _PhotoInLetter extends StatelessWidget {
  const _PhotoInLetter({
    required this.image,
    required this.photoSeed,
    required this.width,
    this.mood = PhotoMood.none,
    this.note,
  });

  final ImageProvider image;
  final PhotoMood mood;
  final String? note;

  /// 照片种子；null = 完全端正（最阅读态）。倾斜 = tiltOf × 0.5（半量）
  final String? photoSeed;

  final double width;

  @override
  Widget build(BuildContext context) {
    final tilt = photoSeed == null
        ? 0.0
        : NatsuImperfection.tiltOf(photoSeed!) * 0.5;
    return Center(
      child: Transform.rotate(
        angle: tilt * math.pi / 180,
        child: PhotoCard(
          image: image,
          seedId: photoSeed ?? 'letter-photo',
          caption: note,
          mood: mood,
          width: width,
          height: width * 0.7,
        ),
      ),
    );
  }
}
