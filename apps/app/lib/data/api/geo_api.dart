/// 逆地理端点：坐标转成可公开展示的城市级地点名。
library;

import '../../core/result.dart';
import 'api_client.dart';

class GeoApi {
  const GeoApi(this._client);

  final ApiClient _client;

  /// 第三方逆地理关闭或不可达时返回 null，不阻断写信落点。
  Future<String?> reverse(double lat, double lon) async {
    try {
      final json = await _client.getJson(
        '/v1/geo/reverse',
        query: {'lat': lat, 'lon': lon},
      );
      final placeLabel = _client.decode<String?>(() {
        if (!json.containsKey('place_label')) {
          throw const FormatException('缺少 place_label');
        }
        final value = json['place_label'];
        if (value == null || value is String) return value as String?;
        throw const FormatException('place_label 必须是字符串或 null');
      });
      return placeLabel;
    } on ApiFailure catch (error) {
      if (error.isDegradable) return null;
      rethrow;
    }
  }
}
