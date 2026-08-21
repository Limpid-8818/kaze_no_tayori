import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../tokens/natsu_tokens.dart';
import 'natsu_skins.dart';

/// 夏の手紙 v2 · 装饰贴纸 — 皮肤资产的散落形态
///
/// 资产的无状态渲染 + 种子倾斜/偏移（Controlled Imperfection：贴纸
/// 从不贴正）。装饰槽资产禁珊瑚（配给制）——贴纸是点缀，不承载
/// 邮戳/邮票的旅行语义。
///
/// 承托纪律（同 StampPiece/Postmark 的既有约定）：SkinDecor 必须贴在
/// 信纸/明信片的 Stack 内（作为 Positioned 后代出现），不独立悬浮于
/// 天空——展示页书桌分区示范正确用法。
class SkinDecor extends StatelessWidget {
  const SkinDecor({
    super.key,
    required this.assetId,
    required this.seedId,
    this.size = 48,
  });

  /// 装饰资产 ID（SkinSlot.decor）；未注册 id 渲染为空——装饰缺失不崩信件
  final String assetId;

  /// 种子 ID（倾斜 + 偏移来源）
  final String seedId;

  /// 竖向基准尺寸（实际宽 = size × aspectRatio）
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = NatsuSkins.byId(assetId);
    if (asset == null) return const SizedBox.shrink();

    final angle = NatsuImperfection.tiltOf(seedId) * math.pi / 180;
    final offset = NatsuImperfection.offsetOf('$seedId/decor');

    return Transform.rotate(
      angle: angle,
      child: Transform.translate(
        offset: offset,
        child: SizedBox(
          width: size * asset.aspectRatio,
          height: size,
          child: CustomPaint(painter: asset.painter, size: Size.infinite),
        ),
      ),
    );
  }
}
