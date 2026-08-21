/// 随机漂流端点（PRD 6.3）。
///
/// 纯随机抽取——不要精准，要偶然（赛道立场在数据层的体现）。
library;

import '../models/letter.dart';
import 'api_client.dart';

class DriftApi {
  const DriftApi(this._client);

  final ApiClient _client;

  /// 抽一封漂来的信。副作用：写入已读，计数 read+1。
  ///
  /// 池空时抛 ApiFailure(driftPoolEmpty)——这是叙事状态
  /// 「此刻还没有漂来的信」，UI 不得当错误弹窗处理。
  Future<LetterPublic> next() async {
    final json = await _client.getJson('/v1/drift/next');
    return LetterPublic.fromJson(json);
  }
}
