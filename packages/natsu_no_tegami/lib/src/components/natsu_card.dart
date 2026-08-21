import 'package:flutter/material.dart';

import '../tokens/natsu_tokens.dart';

/// 夏の手紙 v2 · 卡片 — 纸从天空浮起
///
/// v2 层次语言：纸面（paperWhite / envelope 暖白）+ 极轻墨蓝阴影
/// （[NatsuShadows.paperResting]，纸被空气托起的深度线索）+ paperEdge 纸缘线。
/// [stamp] 槽位预留主题皮肤刻印（配给制：至多一枚，右上角）。
///
/// 实现注记：stamp 用 Stack 定位需要确定的卡片尺寸；无 stamp 时直接
/// 返回内容（兼容 stretch 约束网格）。
class NatsuCard extends StatelessWidget {
  const NatsuCard({
    super.key,
    required this.child,
    this.surface = NatsuCardSurface.paper,
    this.padding = const EdgeInsets.all(NatsuSpacing.cardPadding),
    this.width,
    this.stamp,
    this.hoverShadow = false,
  });

  final Widget child;

  /// 内容表面：白纸 / 暖封
  final NatsuCardSurface surface;

  final EdgeInsetsGeometry padding;

  final double? width;

  /// 角饰刻印（主题皮肤挂点）。配给制纪律：每卡至多一枚。
  final Widget? stamp;

  /// 拈起态阴影（hover 场景由外层控制）
  final bool hoverShadow;

  @override
  Widget build(BuildContext context) {
    final bg = switch (surface) {
      NatsuCardSurface.paper => NatsuColors.paperWhite,
      NatsuCardSurface.envelope => NatsuColors.envelope,
    };

    final decorated = Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(NatsuRadius.card),
        border: NatsuBorders.hairline,
        boxShadow:
            hoverShadow ? NatsuShadows.paperHover : NatsuShadows.paperResting,
      ),
      child: child,
    );

    if (stamp == null) return decorated;

    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          decorated,
          Positioned(top: 0, right: 0, child: stamp!),
        ],
      ),
    );
  }
}

/// 卡片内容表面
enum NatsuCardSurface { paper, envelope }

/// v1 过渡别名
@Deprecated('Use NatsuCardSurface')
typedef NatsuCardPaper = NatsuCardSurface;
