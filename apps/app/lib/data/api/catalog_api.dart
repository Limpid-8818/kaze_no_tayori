/// 静态目录端点：主题与标签。
///
/// 新增主题只加皮肤包（红线 6）；标签是心情速记，不是兴趣画像（红线 2）。
library;

import '../models/catalog.dart';
import 'api_client.dart';

class CatalogApi {
  const CatalogApi(this._client);

  final ApiClient _client;

  /// 裸数组响应，不带 Page 包装。
  Future<List<ThemePublic>> themes() async {
    final list = await _client.getList('/v1/themes');
    return list
        .whereType<Map>()
        .map((e) => ThemePublic.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<TagPublic>> tags() async {
    final list = await _client.getList('/v1/tags');
    return list
        .whereType<Map>()
        .map((e) => TagPublic.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
