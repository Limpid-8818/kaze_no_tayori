/// 反馈提交 API（设置页入口）。
///
/// 类型单选 + 正文，版本/平台由客户端自动附带（用户无感知），服务端
/// 只做截断落库。本期无「我的反馈」历史，提交即完成。
library;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api_client.dart';

/// 反馈类型，与后端 feedback_category 枚举对齐（值小写蛇形）。
enum FeedbackCategory { bug, suggestion }

class FeedbackApi {
  const FeedbackApi(this._client);

  final ApiClient _client;

  Future<void> submit({
    required FeedbackCategory category,
    required String content,
  }) async {
    final info = await PackageInfo.fromPlatform();
    await _client.postJson(
      '/v1/feedback',
      body: {
        'category': category.name,
        'content': content,
        'app_version': info.version,
        'platform': _platformName(),
      },
    );
  }

  static String _platformName() => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'other',
  };
}
