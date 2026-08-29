/// 图片选择桥（抽象）。package:web 只能在 Web 编译，VM 测试不可触及，
/// 平台实现经 `image_picker_gateway.dart` 的条件导出隔离。
library;

import 'dart:typed_data';

abstract class ImagePickerBridge {
  /// 打开系统文件选择；取消返回 null。
  Future<PickedImage?> pickImage();
}

class PickedImage {
  const PickedImage({
    required this.filename,
    required this.contentType,
    required this.bytes,
  });

  final String filename;
  final String contentType;
  final Uint8List bytes;
}
