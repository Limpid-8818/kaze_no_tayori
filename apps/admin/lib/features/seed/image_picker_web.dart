/// Web 平台实现：window 文件选择 → 字节读取（package:web）。
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'image_picker_bridge.dart';

ImagePickerBridge createImagePickerBridge() => WebImagePickerBridge();

class WebImagePickerBridge implements ImagePickerBridge {
  @override
  Future<PickedImage?> pickImage() async {
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = 'image/jpeg,image/png,image/webp';
    // 不挂 DOM 的 input click() 在部分浏览器/嵌入环境会被忽略，且可能被 GC
    web.document.body!.appendChild(input);
    // change 事件回来时 files 已就绪；用户取消选择只发 cancel 不发 change——
    // 两个都监听，否则取消后 Completer 挂死、调用方的「上传中」态永不恢复
    final completer = Completer<web.File?>();
    void finish(web.File? file) {
      if (!completer.isCompleted) completer.complete(file);
      input.remove();
    }

    input.addEventListener(
      'change',
      ((web.Event _) {
        final files = input.files;
        finish(files == null || files.length == 0 ? null : files.item(0));
      }).toJS,
    );
    input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
    input.click();
    final file = await completer.future;
    if (file == null) return null;
    // JSPromise.toDart → JSArrayBuffer；JSArrayBuffer.toDart → ByteBuffer
    final bytes = (await file.arrayBuffer().toDart).toDart.asUint8List();
    return PickedImage(
      filename: file.name,
      contentType: file.type,
      bytes: bytes,
    );
  }
}
