/// 导出管线测试：离屏捕获产出 PNG、照片未就绪整体失败、长信不截断
/// 且超限自动降像素比。
///
/// 测试环境的帧只能靠 pump 驱动，而导出链路含真实异步（照片解码 →
/// 挂载画布 → 等 endOfFrame → 光栅化）：pump 必须循环放帧直到导出
/// 落定，单次 pump 会停在照片解码后的 endOfFrame 上造成死等。全程
/// 包在 tester.runAsync 内放出真实事件循环（包内 letter_export_test
/// 同款纪律）。
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/features/reader/letter_exporter.dart';
import 'package:kazenotayori/features/reader/letter_view.dart';
import 'package:kazenotayori/features/reader/widgets/letter_export_canvas.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../fakes/png_bytes.dart' as png_bytes;

LetterView _view({List<LetterBlock>? blocks}) => LetterView(
  id: 'letter_1',
  blocks: blocks ?? const [TextBlock('傍晚的海边风很大')],
  createdAt: DateTime(2026, 8, 26, 10),
  signature: '赶海的人',
  place: '浙江 · 舟山',
  weatherText: '多云 26°',
);

class _FailingProvider extends ImageProvider<Object> {
  @override
  Future<Object> obtainKey(ImageConfiguration configuration) =>
      Future.error(StateError('photo broken'));

  @override
  ImageStreamCompleter loadImage(Object key, ImageDecoderCallback decode) =>
      throw UnimplementedError();
}

/// 在 runAsync 内启动导出，pump 循环驱动到落定（或 300 帧保险丝）。
Future<(Uint8List?, Object?)> _driveExport(
  WidgetTester tester,
  BuildContext context,
  LetterView view, {
  ImageProvider Function(String ref)? photoResolver,
}) async {
  Uint8List? png;
  Object? error;
  await tester.runAsync(() async {
    final tracked = () async {
      try {
        png = await exportLetterImage(
          context,
          view,
          photoResolver:
              photoResolver ?? ((ref) => throw StateError('unexpected: $ref')),
        );
      } catch (e) {
        error = e;
      }
    }();
    var guard = 0;
    while (png == null && error == null && guard < 300) {
      await tester.pump();
      // pump 返回的可能是已完成的 Future，不真正让路；delayed 在
      // runAsync 区内走真实事件队列，原生解码/光栅化回调才有机会落
      await Future<void>.delayed(Duration.zero);
      guard++;
    }
    await tracked;
  });
  return (png, error);
}

Widget _host(GlobalKey ctxKey) => MaterialApp(
  theme: KazeTheme.light(),
  home: Scaffold(
    body: Builder(
      key: ctxKey,
      builder: (context) => const Center(child: Text('宿主')),
    ),
  ),
);

void main() {
  testWidgets('导出返回 PNG（magic bytes），画布含水印且已随 entry 移除', (tester) async {
    final ctxKey = GlobalKey();
    await tester.pumpWidget(_host(ctxKey));

    final (png, error) = await _driveExport(
      tester,
      ctxKey.currentContext!,
      _view(),
    );

    expect(error, isNull);
    expect(png, isNotNull);
    expect(png!.sublist(0, 8), png_bytes.pngMagic);
    // entry 已在 finally 里移除，画布不残留
    await tester.pumpAndSettle();
    expect(find.byType(LetterExportCanvas), findsNothing);
  });

  testWidgets('照片进缓存成功：PhotoCard 画进导出图', (tester) async {
    final photoBytes = (await tester.runAsync(() => png_bytes.solidPng()))!;
    final ctxKey = GlobalKey();
    await tester.pumpWidget(_host(ctxKey));

    final (png, error) = await _driveExport(
      tester,
      ctxKey.currentContext!,
      _view(
        blocks: [
          const TextBlock('看看这张'),
          PhotoBlock(imageRef: 'http://test/p1.jpg'),
        ],
      ),
      photoResolver: (_) => MemoryImage(photoBytes),
    );

    expect(error, isNull);
    expect(png, isNotNull);
    expect(png!.sublist(0, 8), png_bytes.pngMagic);
  });

  testWidgets('照片未就绪：整体不导，抛 LetterPhotoNotReadyException', (tester) async {
    final ctxKey = GlobalKey();
    await tester.pumpWidget(_host(ctxKey));

    final (png, error) = await _driveExport(
      tester,
      ctxKey.currentContext!,
      _view(blocks: [const PhotoBlock(imageRef: 'http://test/broken.jpg')]),
      photoResolver: (_) => _FailingProvider(),
    );

    expect(png, isNull);
    expect(error, isA<LetterPhotoNotReadyException>());
    // 失败后 entry 也要被移除（finally 兜底）
    await tester.pumpAndSettle();
    expect(find.byType(LetterExportCanvas), findsNothing);
  });

  testWidgets('首次导出（冷图片缓存）：水印 logo 已画入导出图不缺席', (tester) async {
    // 模拟冷启动：清空全局图片缓存，logo 的 asset 加载必须靠导出前的
    // precache 预热，否则首帧光栅化里 logo 位置是纯渐变空白
    PaintingBinding.instance.imageCache.clear();
    final ctxKey = GlobalKey();
    await tester.pumpWidget(_host(ctxKey));

    final (png, error) = await _driveExport(
      tester,
      ctxKey.currentContext!,
      _view(),
    );

    expect(error, isNull);
    expect(png, isNotNull);

    // 解码 PNG：水印 logo 区域（水印 Row 从右缘 64 向左排，logo 占最左
    // 28px）应有高饱和图案像素——logo 缺席时该区域是纯渐变，为 0
    final artworkPixels = await tester.runAsync(() => _logoArtworkPixels(png!));
    expect(artworkPixels, greaterThanOrEqualTo(5));
  });

  testWidgets('长信成一整张长图不截断；像素高超 8192 时像素比 3→2（宽 1120）', (tester) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 每段 38px 高 + 24 间距，60 段 ≈ 3600 逻辑高：×3 超 8192，×2 不超
    final blocks = [for (var i = 0; i < 60; i++) TextBlock('第$i段，海边有风。')];
    final ctxKey = GlobalKey();
    await tester.pumpWidget(_host(ctxKey));

    final (png, error) = await _driveExport(
      tester,
      ctxKey.currentContext!,
      _view(blocks: blocks),
    );

    expect(error, isNull);
    expect(png, isNotNull);
    final byteData = ByteData.sublistView(png!);
    // IHDR：宽 16..20、高 20..24（大端）
    final widthPx = byteData.getUint32(16);
    final heightPx = byteData.getUint32(20);
    expect(widthPx, 1120, reason: '降档后 560 × 2');
    expect(heightPx, greaterThan(1200), reason: '长图远超视口高，未被 Overlay 钳断');
    expect(heightPx, lessThanOrEqualTo(8192), reason: '仍在纹理上限内');
  });
}

/// 水印 logo 与纯背景对照区（逻辑坐标）：水印 Row 从右缘 64 向左排
/// [logo 28][gap 8][风信文字]，logo 占最左侧 28；采样向内缩 2。
/// 对照区取同一水平带的左侧天空留白。
(ui.Rect, ui.Rect) _markAndBgRegions(double canvasH) => (
  ui.Rect.fromLTWH(
    428 + 2,
    canvasH - KazeExportDims.markBottom - KazeExportDims.markLogo + 2,
    KazeExportDims.markLogo - 4,
    KazeExportDims.markLogo - 4,
  ),
  ui.Rect.fromLTWH(
    80,
    canvasH - KazeExportDims.markBottom - KazeExportDims.markLogo + 2,
    24,
    KazeExportDims.markLogo - 4,
  ),
);

/// 解码导出 PNG，统计 logo 区域内的高饱和图案像素数。logo 的图案是
/// 墨蓝（如 60,97,162），而天空 (250,248,241) 与 logo 白底 (253,253,253)
/// 的通道差都在 10 以内——「通道差 > 40」能干净地区分图案与背景；
/// logo 缺席时该区域是纯渐变，图案像素数为 0
Future<int> _logoArtworkPixels(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();
  final w = image.width;
  final h = image.height;
  image.dispose();

  final ratio = w / KazeExportDims.canvasW; // 像素/逻辑比（3 或 2）
  final (logo, _) = _markAndBgRegions(h / ratio);
  var artwork = 0;
  for (
    var y = (logo.top * ratio).round();
    y < (logo.bottom * ratio).round();
    y++
  ) {
    for (
      var x = (logo.left * ratio).round();
      x < (logo.right * ratio).round();
      x++
    ) {
      final o = (y * w + x) * 4;
      final r = bytes[o];
      final g = bytes[o + 1];
      final b = bytes[o + 2];
      if (math.max(r, math.max(g, b)) - math.min(r, math.min(g, b)) > 40) {
        artwork++;
      }
    }
  }
  return artwork;
}
