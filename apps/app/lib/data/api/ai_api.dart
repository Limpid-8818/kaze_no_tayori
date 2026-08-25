/// AI 端点（PRD 6.2，可降级）。
///
/// AI 是桥不是枪手（红线 8）：润色保留原意、短诗由用户采纳。
/// FEATURE_AI=false 时后端 503 feature_disabled → isDegradable，
/// UI 应退到纯手动写信，**不弹红色报错**。
library;

import '../models/common.dart';
import 'api_client.dart';

class AiApi {
  const AiApi(this._client);

  final ApiClient _client;

  Future<PolishResponse> polish(String content) async {
    final json = await _client.postJson(
      '/v1/ai/polish',
      body: {'content': content},
    );
    return _client.decode(() => PolishResponse.fromJson(json));
  }

  Future<PoemResponse> poem(String content) async {
    final json = await _client.postJson(
      '/v1/ai/poem',
      body: {'content': content},
    );
    return _client.decode(() => PoemResponse.fromJson(json));
  }
}
