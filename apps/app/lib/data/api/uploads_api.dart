/// 图片上传端点（PRD 6.1 附图，1–3 张）。
///
/// 只收 bytes 与文件名，不依赖 image_picker——选图/压缩是 F1 写信流的事。
library;

import '../models/common.dart';
import 'api_client.dart';

class UploadsApi {
  const UploadsApi(this._client);

  final ApiClient _client;

  Future<UploadResponse> uploadImage({
    required String filename,
    required List<int> bytes,
    String? contentType,
  }) async {
    final json = await _client.postMultipartBytes(
      '/v1/uploads/images',
      filename: filename,
      bytes: bytes,
      contentType: contentType,
    );
    return _client.decode(() => UploadResponse.fromJson(json));
  }
}
