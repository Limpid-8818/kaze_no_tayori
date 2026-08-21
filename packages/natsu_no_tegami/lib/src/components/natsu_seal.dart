import 'package:flutter/material.dart';

import '../tokens/natsu_tokens.dart';

/// 夏の手紙 v2 · 刻印 — 品牌位专用
///
/// v2 降级说明：刻印不再是通用装饰（那是 v1 的「日式符号」路径），
/// 只出现在品牌位（展示页眉、信封封口）。珊瑚色，配给制至多一枚。
class NatsuSeal extends StatelessWidget {
  const NatsuSeal({
    super.key,
    this.character = '夏',
    this.size = 56,
  });

  /// 刻印文字（单字为宜）。
  final String character;

  /// 印面尺寸。
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: NatsuColors.paperWhite,
        border: Border.all(color: NatsuColors.coralStamp, width: 1.5),
        borderRadius: BorderRadius.circular(NatsuRadius.stamp),
        boxShadow: NatsuShadows.paperResting,
      ),
      alignment: Alignment.center,
      child: Text(
        character,
        style: NatsuTypography.hwSeal.copyWith(
          fontSize: size * 0.62,
          height: 1.0,
        ),
      ),
    );
  }
}
