/// 随机漂流端点（PRD 6.3）。
///
/// 纯随机抽取——不要精准，要偶然（赛道立场在数据层的体现）。
library;

import '../models/letter.dart';
import 'api_client.dart';

class DriftApi {
  const DriftApi(this._client);

  final ApiClient _client;

  /// 抽一封漂来的信。收信 ≠ 已读：抽取只做送达去重，不计数。
  /// 信纸真正打开时需另调 [LettersApi.markRead]（read_count 唯一自增点）。
  ///
  /// 池空时抛 ApiFailure(driftPoolEmpty)——这是叙事状态
  /// 「此刻还没有漂来的信」，UI 不得当错误弹窗处理。
  Future<LetterPublic> next() async {
    final json = await _client.getJson('/v1/drift/next');
    return _client.decode(() => LetterPublic.fromJson(json));
  }
}
