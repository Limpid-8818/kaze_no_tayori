/// 就地发掘端点（PRD 6.4）。
///
/// ST_DWithin 半径检索，按 created_at DESC——**不按热度**（红线 4）。
library;

import '../models/common.dart';
import '../models/letter.dart';
import 'api_client.dart';

class DiscoverApi {
  const DiscoverApi(this._client);

  final ApiClient _client;

  /// 检索附近的「留在这里」。radiusM 缺省由后端取 DISCOVER_RADIUS_M。
  Future<Page<LetterPublic>> list({
    required double lat,
    required double lon,
    int? radiusM,
    int? limit,
  }) async {
    final query = <String, dynamic>{'lat': lat, 'lon': lon};
    if (radiusM != null) query['radius_m'] = radiusM;
    if (limit != null) query['limit'] = limit;
    final json = await _client.getJson('/v1/discover', query: query);
    return _client.decode(() => Page.fromJson(json, LetterPublic.fromJson));
  }
}
