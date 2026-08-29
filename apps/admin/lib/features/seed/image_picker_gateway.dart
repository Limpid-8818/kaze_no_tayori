/// 条件导出：抽象恒可见；实现按平台切换（Web → 真文件选择，其余 → Noop）。
library;

export 'image_picker_bridge.dart' show ImagePickerBridge, PickedImage;
export 'image_picker_noop.dart' if (dart.library.html) 'image_picker_web.dart';
