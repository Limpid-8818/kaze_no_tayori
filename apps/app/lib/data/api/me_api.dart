/// 「我的」端点（PRD 6.5 / 6.10）。
///
/// LetterOwned 只出现在 /v1/me/*——含 status 与自己的落点坐标，
/// 但仍不含 owner_user_id（自己不需要看自己的 id）。
library;

import '../models/common.dart';
import '../models/letter.dart';
import '../models/notification.dart';
import 'api_client.dart';

class MeApi {
  const MeApi(this._client);

  final ApiClient _client;

  /// 我的信，含 pending。List 排序只允许 created_at（红线 4）。
  Future<Page<LetterOwned>> myLetters({int? limit}) async {
    final json = await _client.getJson(
      '/v1/me/letters',
      query: limit == null ? null : {'limit': limit},
    );
    return _client.decode(() => Page.fromJson(json, LetterOwned.fromJson));
  }

  /// 下架我的信（taken_down，非硬删）。回信链不塌。
  Future<void> deleteLetter(String letterId) async {
    await _client.delete('/v1/me/letters/$letterId');
  }

  /// 不再显示（deleted_at 软删位，列表彻底不返回）。仅已退场的信可隐藏，
  /// 公开中/审核中先下架（服务端 409 letter_not_retired）。非硬删，回信链不塌。
  Future<void> hideLetter(String letterId) async {
    await _client.postJson('/v1/me/letters/$letterId/hide');
  }

  /// 抄本列表。
  Future<Page<LetterPublic>> scripbook({int? limit}) async {
    final json = await _client.getJson(
      '/v1/me/scripbook',
      query: limit == null ? null : {'limit': limit},
    );
    return _client.decode(() => Page.fromJson(json, LetterPublic.fromJson));
  }

  /// 收进抄本。204。
  Future<void> addScripbook(ScripbookAddRequest req) async {
    await _client.postJson('/v1/me/scripbook', body: req.toJson());
  }

  /// 移出抄本。204。
  Future<void> removeScripbook(String letterId) async {
    await _client.delete('/v1/me/scripbook/$letterId');
  }

  /// 回信列表。
  Future<Page<NotificationPublic>> notifications({
    bool? unreadOnly,
    int? limit,
  }) async {
    final query = <String, dynamic>{};
    if (unreadOnly != null) query['unread_only'] = unreadOnly;
    if (limit != null) query['limit'] = limit;
    final json = await _client.getJson(
      '/v1/me/notifications',
      query: query.isEmpty ? null : query,
    );
    return _client.decode(
      () => Page.fromJson(json, NotificationPublic.fromJson),
    );
  }

  /// 标记已读。204。
  Future<void> markNotificationRead(String notificationId) async {
    await _client.postJson('/v1/me/notifications/$notificationId/read');
  }
}
