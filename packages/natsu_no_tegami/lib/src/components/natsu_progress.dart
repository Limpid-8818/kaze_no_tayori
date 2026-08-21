import 'package:flutter/material.dart';

import '../tokens/natsu_tokens.dart';

/// 夏の手紙 · 进度条
///
/// 4px 药丸：纸缘底轨 + 夏空蓝填充。
/// - determinate：value ∈ [0,1]， AnimatedContainer 平滑过渡
/// - indeterminate（value 省略）：480ms/循环的 0.3 宽扫光来回——「风送信」
///
/// UI 骨架 — 0°、无阴影。全宽拉伸（SizedBox.expand 语义），高度固定。
class NatsuProgress extends StatefulWidget {
  const NatsuProgress({super.key, this.value});

  /// 进度 0..1；null = 不定模式（加载中）
  final double? value;

  @override
  State<NatsuProgress> createState() => _NatsuProgressState();
}

class _NatsuProgressState extends State<NatsuProgress>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.value != null) {
      final f = widget.value!.clamp(0.0, 1.0);
      _controller?.dispose();
      _controller = null;
      return _Track(
        child: AnimatedFractionallySizedBox(
          duration: NatsuMotion.short,
          curve: NatsuMotion.easing,
          widthFactor: f,
          child: const _Fill(),
        ),
      );
    }

    // 不定模式：扫光完整走过轨道。用 Positioned 直接表达几何（Align 的
    // 中心点换算易错）：t=0 扫光整体在轨道左外（left = -轨道宽×sweep），
    // t=1 整体在右外（left = 轨道宽）。轨道有 clip，出入即裁切。
    _controller ??= AnimationController(
      vsync: this,
      duration: NatsuMotion.drift,
    )..repeat();
    const sweep = 0.3;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller!,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final left = -w * sweep + _controller!.value * w * (1 + sweep);
            return _Track(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: left,
                    top: 0,
                    bottom: 0,
                    width: w * sweep,
                    child: const _Fill(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: NatsuSpacing.progressH,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: NatsuColors.paperEdge,
        borderRadius: BorderRadius.circular(NatsuSpacing.progressH / 2),
      ),
      child: child,
    );
  }
}

class _Fill extends StatelessWidget {
  const _Fill();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: NatsuSpacing.progressH,
      decoration: BoxDecoration(
        color: NatsuColors.skyBlue,
        borderRadius: BorderRadius.circular(NatsuSpacing.progressH / 2),
      ),
    );
  }
}
