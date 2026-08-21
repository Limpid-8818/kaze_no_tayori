import 'dart:typed_data' show Uint8List;
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/widgets.dart';

/// 夏の手紙 v2 · 信件导出 — 把一封信渲染为匿名图片
///
/// 两层 API：
/// - [LetterExportBoundary] 把信圈进 RepaintBoundary（key 由调用方持有，
///   因为「导出」按钮与信本身通常分处 widget 树两支）；
/// - [captureLetterPng] 光栅化为 PNG 字节（web/桌面/移动通用）。
///
/// 匿名性由组件 API 天然保证：LetterReading 无作者字段——导出即所见，
/// 渲染什么就导出什么；匿名策略 = 不向被捕获的子树传作者信息。
///
/// 保存到相册/下载属 App 层职责，组件库只产出字节。
///
/// 使用注意：
/// - 照片须先 `precacheImage` 完成再捕获，否则导出灰块；
/// - 若捕获时 boundary 尚待绘制（debugNeedsPaint），先
///   `await WidgetsBinding.instance.endOfFrame` 再重试一次。
class LetterExportBoundary extends StatelessWidget {
  const LetterExportBoundary({
    super.key,
    required this.child,
    this.boundaryKey,
  });

  final Widget child;

  /// 圈住 child 的 RepaintBoundary key（调用方持有用于捕获）。
  /// RepaintBoundary 的 State 是私有类型，故用裸 GlobalKey——
  /// 从 currentContext.findRenderObject() 即得 RenderRepaintBoundary。
  final GlobalKey? boundaryKey;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(key: boundaryKey, child: child);
  }
}

/// 捕获 boundary 内当前帧为 PNG；未挂载/未布局时返回 null（不抛）。
Future<Uint8List?> captureLetterPng(
  GlobalKey boundaryKey, {
  double pixelRatio = 2.0,
}) async {
  final ctx = boundaryKey.currentContext;
  if (ctx == null) return null;
  final boundary = ctx.findRenderObject();
  if (boundary is! RenderRepaintBoundary || boundary.debugNeedsPaint) {
    return null;
  }
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ImageByteFormat.png);
  image.dispose();
  return data?.buffer.asUint8List();
}
