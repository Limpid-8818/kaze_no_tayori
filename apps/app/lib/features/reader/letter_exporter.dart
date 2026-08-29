/// 信件导出管线 — 导出画布离屏挂载 → 光栅化为 PNG 字节。
///
/// 捕获用设计系统的 LetterExportBoundary/captureLetterPng（组件库只产
/// 字节，存相册/分享是 App 层职责）。离屏挂载经 OverlayEntry 把画布放到
/// 屏幕外（left: -9999）：仍参与布局与绘制，但不打扰用户。Overlay 的
/// Positioned 子项在未同时指定 top/bottom（或 height）时高度约束无界
/// （RenderStack 语义），画布按内容撑到自然高度——长信成一整张长图；
/// RepaintBoundary 出图按自身尺寸（OffsetLayer.toImage），不受 Stack
/// 裁剪影响。
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../app/theme.dart';
import 'letter_view.dart';
import 'widgets/letter_export_canvas.dart';

/// 信里有照片还没下载完（硬导会出灰块），调用方捕获后提示联网重试。
class LetterPhotoNotReadyException implements Exception {
  const LetterPhotoNotReadyException(this.ref);

  /// 未就绪的照片引用（排查用）
  final String ref;

  @override
  String toString() => 'LetterPhotoNotReadyException: $ref';
}

/// 把一封信渲染导出为 PNG 字节（长图，像素宽 = 560 × pixelRatio）。
///
/// [photoResolver] 默认走缓存网络图；测试注入 MemoryImage/失败实现。
/// 抛 [LetterPhotoNotReadyException] 表示照片未就绪；画布始终没画出来
/// 属于框架异常，抛 StateError。使用方保证 context 挂在 Overlay 下。
Future<Uint8List> exportLetterImage(
  BuildContext context,
  LetterView view, {
  ImageProvider Function(String ref) photoResolver = cachedPhotoResolver,
}) async {
  // Overlay 在进入异步前先取好：precache 的间隙后 context 可能已失效
  final overlay = Overlay.of(context, rootOverlay: true);

  // 水印 logo 预热。asset 首次加载是异步的，不进缓存的话首次导出的
  // 首帧里 logo 位置是空白（第二次起命中图片缓存才正常）。future 在
  // 同步段就启动（context 未跨异步间隙），与照片预热并行；失败不阻断
  // 导出——水印非关键内容，logo 缺席好过整封导不出。
  final logoPrecache = precacheImage(
    const AssetImage(LetterExportCanvas.logoAsset),
    context,
    onError: (Object _, StackTrace? _) {},
  );

  // 照片先全部进图片缓存再捕获，否则导出灰块（组件库 letter_export
  // 头注的注意事项）；任一张失败即整体失败，宁可不导也不出坏图。
  // 注意：precacheImage 的 future 出错也正常完成（不 complete with
  // error），失败只能经 onError 参数收集。
  final refs = {
    for (final block in view.blocks)
      if (block is PhotoBlock) block.imageRef,
  };
  for (final ref in refs) {
    Object? failure;
    await precacheImage(
      photoResolver(ref),
      context,
      onError: (Object e, StackTrace? _) => failure = e,
    );
    if (failure != null) throw LetterPhotoNotReadyException(ref);
  }
  await logoPrecache;

  final boundaryKey = GlobalKey();
  OverlayEntry? entry;
  try {
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999,
        top: 0,
        width: KazeExportDims.canvasW,
        child: LetterExportBoundary(
          boundaryKey: boundaryKey,
          child: LetterExportCanvas(
            blocks: view.blocks,
            photoResolver: photoResolver,
            seedId: view.id,
            place: view.place,
            time: view.timeLabel,
            dayPeriod: view.dayPeriod,
            weather: view.weatherText,
            signature: view.signature,
            poem: view.poem,
            readCount: view.readCount,
            interactionCount: view.interactionCount,
            replyCount: view.replyCount,
            skyGradient: skyOfLetter(view),
          ),
        ),
      ),
    );
    overlay.insert(entry);

    final binding = WidgetsBinding.instance;
    await binding.endOfFrame;
    // 再等一帧：预热命中的图片流若经微任务迟到（而非同步交付），补画
    // 落在第二帧——只等一帧会间歇性拍到 logo/照片空白（竞态）
    await binding.endOfFrame;

    // 高度落定后才定像素比：默认 3x 出高清长图，超高信逐级降档
    // （3→2→1）保住设备纹理上限——只降一档在叙事计数区加入后不够
    final box = boundaryKey.currentContext?.findRenderObject();
    final height = box is RenderBox ? box.size.height : 0.0;
    var ratio = 3.0;
    while (height * ratio > KazeExportDims.maxTexPx && ratio > 1) {
      ratio -= 1;
    }

    var png = await captureLetterPng(boundaryKey, pixelRatio: ratio);
    if (png == null) {
      // boundary 尚待绘制：等一帧重试一次（组件库注释口径）
      await binding.endOfFrame;
      png = await captureLetterPng(boundaryKey, pixelRatio: ratio);
    }
    if (png == null) {
      throw StateError('导出捕获失败：画布未挂载或未绘制');
    }
    return png;
  } finally {
    entry?.remove();
  }
}
