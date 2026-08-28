/// 测试用图片字节 — 纯色 4×4 PNG。
///
/// toImage/toByteData 的 PNG 编码走真实异步（平台线程），testWidgets 的
/// FakeAsync 区等不到回调——生成与消费都要放进 tester.runAsync。
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color;

/// PNG magic bytes（\x89 P N G \r \n \x1a \n）
const List<int> pngMagic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

Future<Uint8List> solidPng([Color color = const Color(0xFFFFFFFF)]) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
      .drawRect(const ui.Rect.fromLTWH(0, 0, 4, 4), ui.Paint()..color = color);
  final image = await recorder.endRecording().toImage(4, 4);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
