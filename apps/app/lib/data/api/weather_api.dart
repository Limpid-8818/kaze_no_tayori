/// 天气端点：按坐标查询当前天气。
///
/// 天气是可降级模块（PRD §8.3），取不到返回 null，不影响写信。
library;

import '../../core/result.dart';
import '../models/letter.dart';
import 'api_client.dart';

class WeatherApi {
  const WeatherApi(this._client);

  final ApiClient _client;

  /// 按坐标查询当前天气。取不到时返回 null。
  Future<Weather?> getCurrentWeather(double lat, double lon) async {
    try {
      final json = await _client.getJson(
        '/v1/weather/now',
        query: {'lat': lat, 'lon': lon},
      );
      if (json.isEmpty) return null;
      return Weather.fromJson(json);
    } on ApiFailure catch (e) {
      // 可降级模块失败时温和返回 null，不弹红框
      if (e.isDegradable) return null;
      rethrow;
    }
  }
}
