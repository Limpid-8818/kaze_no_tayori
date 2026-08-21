import 'package:flutter/material.dart';

import '../../tokens/natsu_tokens.dart';

/// 夏の手紙 v2 · 旅行者的书桌 — Controlled Imperfection 总演示
///
/// Stack + Positioned 散落布局：信纸、照片、邮票、邮戳是「摊在桌上的东西」，
/// 各带种子倾斜与偏移；而承载它们的网格与标题永远 0°。
/// [animateIn]：纸张落桌入场——每张从 offset(0,-16)+透明 落到种子位，
/// 80ms stagger、drift 曲线（风送来的）。
///
/// 用法：children 里放已 Positioned 定位的 LetterPaper/PhotoCard/…。
class DeskScene extends StatefulWidget {
  const DeskScene({
    super.key,
    required this.height,
    this.children = const [],
    this.animateIn = true,
  });

  /// 桌面高度（Stack 需要确定高度定位散落物）
  final double height;

  final List<Widget> children;

  final bool animateIn;

  @override
  State<DeskScene> createState() => _DeskSceneState();
}

class _DeskSceneState extends State<DeskScene> {
  @override
  void initState() {
    super.initState();
    if (widget.animateIn) {
      // stagger 触发：每张纸延迟 80ms 依次落桌
      Future.wait([
        for (var i = 0; i < widget.children.length; i++)
          Future.delayed(
            Duration(milliseconds: 80 * i),
            () => mounted ? setState(() {}) : null,
          ),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (i, child) in widget.children.indexed)
            // 注记：_FallingPiece 必须在 Positioned 之内——ParentData
            // 不穿透非 RenderObjectWidget，Transform 包在 Positioned 外
            // 会让 Stack 拿不到定位。
            _wrapPositioned(
              i,
              child,
              _FallingPiece(
                delay: Duration(milliseconds: 80 * i),
                animate: widget.animateIn,
                child: _stripPositioned(child),
              ),
            ),
        ],
      ),
    );
  }

  /// DeskScene 约定 children 直接放 Positioned（或裸 widget）。
  /// 这里拆出定位参数，动画件放进 Positioned 内部，再按原位摆回。
  Widget _wrapPositioned(int i, Widget child, Widget inner) {
    final parentData = _readPosition(child);
    return Positioned(
      left: parentData?.$1,
      top: parentData?.$2,
      right: parentData?.$3,
      bottom: parentData?.$4,
      width: parentData?.$5,
      height: parentData?.$6,
      child: inner,
    );
  }

  (double?, double?, double?, double?, double?, double?)? _readPosition(
      Widget w) {
    if (w is Positioned) {
      return (w.left, w.top, w.right, w.bottom, w.width, w.height);
    }
    return null;
  }

  Widget _stripPositioned(Widget w) {
    if (w is Positioned) return w.child;
    return w;
  }
}

/// 单张落桌动画（drift 曲线）
class _FallingPiece extends StatefulWidget {
  const _FallingPiece({
    required this.delay,
    required this.animate,
    required this.child,
  });

  final Duration delay;

  final bool animate;

  final Widget child;

  @override
  State<_FallingPiece> createState() => _FallingPieceState();
}

class _FallingPieceState extends State<_FallingPiece>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NatsuMotion.drift,
  );

  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: NatsuMotion.driftEasing,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) return widget.child;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = _animation.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -16 * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
