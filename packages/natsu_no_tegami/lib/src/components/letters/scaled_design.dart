import 'package:flutter/material.dart';

/// 夏の手紙 v2 · 基准设计呈现 — 素材 SVG 化的统一模式
///
/// 「同一设计，等比呈现」：子树按基准坐标 [baseWidth] × [baseHeight] 固定
/// 设计，整体经 `Transform.scale` 缩放到目标 [width]——素材不管在哪里
/// 显示、显示多大，都是同一份设计的等比缩放：内部所有 px（字号、间距、
/// 线宽、锯齿步距）随整体缩放，相对位置与视觉表现不变。像 SVG 的
/// viewBox：开箱拿来即用，随意缩放。
///
/// OverflowBox 阻断外层约束下传（Transform 是绘制期变换，不隔离布局
/// 约束——没有它，窄容器会把紧约束传进基准设计导致重排）：基准设计
/// 永远在自己的坐标系里布局，只在绘制期缩放。
///
/// 适合固定构图的素材（邮票/邮戳/封筒）。变宽素材（一行文字的落地戳）
/// 与装用户照片的相纸不适用——它们用参数化缩放。
class ScaledDesign extends StatelessWidget {
  const ScaledDesign({
    super.key,
    required this.baseWidth,
    required this.baseHeight,
    required this.width,
    required this.child,
  })  : assert(width > 0),
        assert(baseWidth > 0),
        assert(baseHeight > 0);

  /// 基准设计宽（viewBox 宽）——child 全部按它布局
  final double baseWidth;

  /// 基准设计高（viewBox 高）
  final double baseHeight;

  /// 呈现宽；高 = width × (baseHeight / baseWidth)
  final double width;

  /// 基准设计内容——在 baseWidth × baseHeight 坐标系里布局的子树
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * baseHeight / baseWidth,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: baseWidth,
        maxWidth: baseWidth,
        minHeight: baseHeight,
        maxHeight: baseHeight,
        child: Transform.scale(
          scale: width / baseWidth,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: baseWidth,
            height: baseHeight,
            child: child,
          ),
        ),
      ),
    );
  }
}
