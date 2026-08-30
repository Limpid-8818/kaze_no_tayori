/// 管理端点封装（契约 docs/API_CONTRACT.md §3「管理端」）。
///
/// 每方法一个端点；解析错误经 [ApiClient.decode] 收束为 invalidResponse。
library;

import '../../core/result.dart';
import '../models/admin.dart';
import '../models/enums.dart';
import 'api_client.dart';

class AdminApi {
  const AdminApi(this._client);

  final ApiClient _client;

  // ---------- 会话 ----------

  Future<String> login(String username, String password) async {
    final body = await _client.postJson(
      '/v1/admin/login',
      body: {'username': username, 'password': password},
    );
    final token = body['access_token'];
    if (token is! String || token.isEmpty) {
      throw const ApiFailure(
        ApiErrorKind.invalidResponse,
        '登录响应缺少 access_token',
        code: 'invalid_response',
      );
    }
    return token;
  }

  // ---------- 统计 ----------

  Future<AdminStats> stats() async {
    final body = await _client.getJson('/v1/admin/stats');
    return _client.decode(() => AdminStats.fromJson(body));
  }

  // ---------- 信件 ----------

  Future<AdminPage<AdminLetterSummary>> letters({
    LetterStatus? status,
    DeliveryMode? deliveryMode,
    String? owner,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (status != null) query['status'] = status.name;
    if (deliveryMode != null) query['delivery_mode'] = deliveryMode.name;
    if (owner != null) query['owner'] = owner;
    final body = await _client.getJson('/v1/admin/letters', query: query);
    return _client.decode(
      () => AdminPage.fromJson(body, AdminLetterSummary.fromJson),
    );
  }

  Future<AdminLetterDetail> letter(String id) async {
    final body = await _client.getJson('/v1/admin/letters/$id');
    return _client.decode(() => AdminLetterDetail.fromJson(body));
  }

  /// 状态机流转。表外流转后端 409 invalid_transition → ApiErrorKind.conflict。
  Future<AdminLetterDetail> transitionLetter(
    String id,
    LetterStatus to, {
    String? note,
  }) async {
    final body = await _client.patchJson(
      '/v1/admin/letters/$id/status',
      body: {'status': to.name, 'note': ?note},
    );
    return _client.decode(() => AdminLetterDetail.fromJson(body));
  }

  // ---------- 举报 ----------

  Future<AdminPage<AdminReport>> reports({
    ReportStatus? status,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (status != null) query['status'] = status.name;
    final body = await _client.getJson('/v1/admin/reports', query: query);
    return _client.decode(() => AdminPage.fromJson(body, AdminReport.fromJson));
  }

  Future<AdminReport> updateReport(
    String id, {
    ReportStatus? status,
    String? adminNote,
  }) async {
    final body = await _client.patchJson(
      '/v1/admin/reports/$id',
      body: {'status': ?status?.name, 'admin_note': ?adminNote},
    );
    return _client.decode(() => AdminReport.fromJson(body));
  }

  // ---------- 反馈 ----------

  Future<AdminPage<AdminFeedback>> feedbacks({
    FeedbackStatus? status,
    FeedbackCategory? category,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (status != null) query['status'] = status.name;
    if (category != null) query['category'] = category.name;
    final body = await _client.getJson('/v1/admin/feedbacks', query: query);
    return _client.decode(
      () => AdminPage.fromJson(body, AdminFeedback.fromJson),
    );
  }

  Future<AdminFeedback> updateFeedback(
    String id, {
    FeedbackStatus? status,
    String? adminNote,
  }) async {
    final body = await _client.patchJson(
      '/v1/admin/feedbacks/$id',
      body: {'status': ?status?.name, 'admin_note': ?adminNote},
    );
    return _client.decode(() => AdminFeedback.fromJson(body));
  }

  // ---------- 种子信 ----------

  Future<AdminPage<AdminLetterSummary>> seedLetters({int limit = 50}) async {
    final body = await _client.getJson(
      '/v1/admin/seed-letters',
      query: {'limit': limit},
    );
    return _client.decode(
      () => AdminPage.fromJson(body, AdminLetterSummary.fromJson),
    );
  }

  /// 新建种子信：body 同写信创建，owner=NULL、直接 public。
  Future<AdminLetterDetail> createSeedLetter(Map<String, dynamic> body) async {
    final resp = await _client.postJson('/v1/admin/seed-letters', body: body);
    return _client.decode(() => AdminLetterDetail.fromJson(resp));
  }

  /// 编辑种子信（theme 不可传；仅限无主信）。
  Future<AdminLetterDetail> updateSeedLetter(
    String id,
    Map<String, dynamic> body,
  ) async {
    final resp = await _client.patchJson(
      '/v1/admin/seed-letters/$id',
      body: body,
    );
    return _client.decode(() => AdminLetterDetail.fromJson(resp));
  }

  // ---------- AI 辅助（采纳制：返回候选，不直接落库） ----------

  /// 润色正文，保留原意。FEATURE_AI=false → 503 feature_disabled（可降级）。
  Future<String> polish(String content) async {
    final body = await _client.postJson(
      '/v1/ai/polish',
      body: {'content': content},
    );
    return _client.decode(() {
      final polished = body['polished'];
      if (polished is! String) {
        throw const FormatException('polished 应为字符串');
      }
      return polished;
    });
  }

  /// 从正文提取意象生成俳句（默认体裁）。候选 ≤4 行的校验在 UI 层。
  Future<String> poem(String content) async {
    final body = await _client.postJson(
      '/v1/ai/poem',
      body: {'content': content},
    );
    return _client.decode(() {
      final poem = body['poem'];
      if (poem is! String) {
        throw const FormatException('poem 应为字符串');
      }
      return poem;
    });
  }

  // ---------- 上传（种子信配图） ----------

  Future<String> uploadImage({
    required String filename,
    required List<int> bytes,
    required String contentType,
  }) async {
    final body = await _client.postMultipartBytes(
      '/v1/uploads/images',
      filename: filename,
      bytes: bytes,
      contentType: contentType,
    );
    final url = body['url'];
    if (url is! String || url.isEmpty) {
      throw const ApiFailure(
        ApiErrorKind.invalidResponse,
        '上传响应缺少 url',
        code: 'invalid_response',
      );
    }
    return url;
  }
}
