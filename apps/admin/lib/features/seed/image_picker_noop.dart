/// 非 Web 平台缺省实现：无文件选择，恒返回 null。
library;

import 'image_picker_bridge.dart';

ImagePickerBridge createImagePickerBridge() => _NoopImagePickerBridge();

class _NoopImagePickerBridge implements ImagePickerBridge {
  @override
  Future<PickedImage?> pickImage() async => null;
}
