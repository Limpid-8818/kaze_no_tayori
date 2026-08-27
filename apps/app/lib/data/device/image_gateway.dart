/// 图片选择的窄接口，避免 feature 与 image_picker 类型耦合
/// （仿 location_gateway.dart 的 gateway 模式，F2 写信附图用）。
///
/// 平台层在 pick 时就限制长边与质量（2048/90），后端还会再压一道
/// （长边 ≤1600 JPEG q82），两端各守一道，客户端原图永不外发。
library;

import 'package:image_picker/image_picker.dart';

class PickedImage {
  const PickedImage({required this.bytes, required this.mime});

  final List<int> bytes;

  /// 按实际字节嗅探出的 MIME（jpeg/png/webp）；null = 无法识别，拒收。
  final String? mime;
}

abstract interface class ImageGateway {
  /// 唤起系统选图器，至多 [maxCount] 张，返回已读字节与嗅探结果。
  Future<List<PickedImage>> pickImages({required int maxCount});
}

class ImagePickerGateway implements ImageGateway {
  const ImagePickerGateway();

  @override
  Future<List<PickedImage>> pickImages({required int maxCount}) async {
    final files = await ImagePicker().pickMultiImage(
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
      // Android 13+ 走系统 Photo Picker，不需要存储权限；
      // 不取全量元数据可避开旧平台的隐式权限
      requestFullMetadata: false,
    );
    final picked = <PickedImage>[];
    for (final file in files.take(maxCount)) {
      final bytes = await file.readAsBytes();
      picked.add(PickedImage(bytes: bytes, mime: sniffImageMime(bytes)));
    }
    return picked;
  }
}

/// 按实际字节识别图片 MIME——不信任扩展名，也不信任平台报告的类型。
///
/// 后端白名单是 image/jpeg | image/png | image/webp，这里只嗅探这三种。
/// iOS 的 HEIC 在 image_picker 设置 imageQuality 后会被平台转码为
/// JPEG（本项目无 macOS 环境，此路径待真机验证，见 F2 路线图）。
String? sniffImageMime(List<int> bytes) {
  bool at(int i, int v) => bytes.length > i && bytes[i] == v;

  if (at(0, 0xFF) && at(1, 0xD8) && at(2, 0xFF)) return 'image/jpeg';
  const pngHeader = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  var isPng = true;
  for (var i = 0; i < pngHeader.length; i++) {
    if (!at(i, pngHeader[i])) {
      isPng = false;
      break;
    }
  }
  if (isPng) return 'image/png';
  if (at(0, 0x52) &&
      at(1, 0x49) &&
      at(2, 0x46) &&
      at(3, 0x46) && // RIFF
      at(8, 0x57) &&
      at(9, 0x45) &&
      at(10, 0x42) &&
      at(11, 0x50)) {
    return 'image/webp';
  }
  return null;
}
