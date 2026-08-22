/// 信件端点：创作、阅读、回信、共鸣、举报。
///
/// 回信与共鸣的 REST 路径都挂在 /v1/letters/{id}/ 下，归此类。
/// 回信是独立作品（红线 3）：这里返回的是 LetterOwned，不是任何私信形状。
library;

import '../models/common.dart';
import '../models/letter.dart';
import 'api_client.dart';

class LettersApi {
  const LettersApi(this._client);

  final ApiClient _client;

  /// 写信 / 投信。返回本人视角（含 status：pending/public/…）。
  Future<LetterOwned> create(LetterCreateRequest req) async {
    final json = await _client.postJson('/v1/letters', body: req.toJson());
    return LetterOwned.fromJson(json);
  }

  /// 读一封公开信。非 public 一律 404（pending 不泄漏存在性）。
  /// 纯读无副作用——开信上报另调 [markRead]。
  Future<LetterPublic> get(String letterId) async {
    final json = await _client.getJson('/v1/letters/$letterId');
    return LetterPublic.fromJson(json);
  }

  /// 开信上报（收信 ≠ 已读）。204；幂等：首开 read_count+1，重复开不再计。
  /// 信纸真正打开时调用（drift 解开封面 / discover 点开列表项皆然）。
  Future<void> markRead(String letterId) async {
    await _client.postJson('/v1/letters/$letterId/read');
  }

  /// 举报。204 无 body。
  Future<void> report(String letterId, ReportRequest req) async {
    await _client.postJson('/v1/letters/$letterId/report', body: req.toJson());
  }

  /// 回信：复用写信请求，parent 预置。原信作者只会收到 Notification。
  Future<LetterOwned> createReply(
    String parentLetterId,
    LetterCreateRequest req,
  ) async {
    final json = await _client.postJson(
      '/v1/letters/$parentLetterId/replies',
      body: req.toJson(),
    );
    return LetterOwned.fromJson(json);
  }

  /// 某封信的公开回信列表。
  Future<Page<LetterPublic>> listReplies(String letterId) async {
    final json = await _client.getJson('/v1/letters/$letterId/replies');
    return Page.fromJson(json, LetterPublic.fromJson);
  }

  /// ✦ 共鸣。幂等：重复调用不涨计数。note 携带时另计 voice。
  Future<ResonanceResponse> addResonance(
    String letterId, {
    String? note,
  }) async {
    final json = await _client.postJson(
      '/v1/letters/$letterId/resonance',
      body: ResonanceRequest(note: note).toJson(),
    );
    return ResonanceResponse.fromJson(json);
  }
}
