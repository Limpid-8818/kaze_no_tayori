/// 通用模型：分页容器、认证、AI、共鸣、抄本、举报、上传的小响应体。
///
/// 字段名与后端 app/schemas/common.py 严格同名（见 docs/API_CONTRACT.md）。
/// 响应模型 `createToJson: false`——只进不出，少生成一半代码。
library;

import 'package:json_annotation/json_annotation.dart';

part 'common.g.dart';

// ---------- 分页 ----------

/// 后端统一分页信封：`{items: [...], next_cursor: null}`。
///
/// v1 契约 next_cursor 恒为 null（不做翻页），但字段保留以兼容后续。
/// json_serializable 对泛型容器支持差，手写 15 行最省且类型安全。
class Page<T> {
  const Page({required this.items, this.nextCursor});

  factory Page.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromItem,
  ) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('分页响应缺少 items 数组');
    }

    final items = <T>[];
    for (var index = 0; index < rawItems.length; index++) {
      final rawItem = rawItems[index];
      if (rawItem is! Map) {
        throw FormatException('items[$index] 不是 JSON 对象');
      }
      items.add(fromItem(Map<String, dynamic>.from(rawItem)));
    }

    final nextCursor = json['next_cursor'];
    if (nextCursor != null && nextCursor is! String) {
      throw const FormatException('next_cursor 必须是字符串或 null');
    }
    return Page(items: items, nextCursor: nextCursor as String?);
  }

  final List<T> items;
  final String? nextCursor;
}

// ---------- 认证（PRD 6.13）----------

/// device_id 换回的 JWT。user_id 只用于本地身份延续，不对外展示。
@JsonSerializable(createToJson: false)
class TokenResponse {
  const TokenResponse({
    required this.accessToken,
    required this.tokenType,
    required this.userId,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) =>
      _$TokenResponseFromJson(json);

  @JsonKey(name: 'access_token')
  final String accessToken;

  /// 恒为 "bearer"；字段属于契约必填，缺失时必须显式报协议错误。
  @JsonKey(name: 'token_type')
  final String tokenType;

  @JsonKey(name: 'user_id')
  final String userId;
}

// ---------- AI（可降级：503 feature_disabled）----------

@JsonSerializable(createToJson: false)
class PolishResponse {
  const PolishResponse({required this.polished});

  factory PolishResponse.fromJson(Map<String, dynamic> json) =>
      _$PolishResponseFromJson(json);

  final String polished;
}

@JsonSerializable(createToJson: false)
class PoemResponse {
  const PoemResponse({required this.poem});

  factory PoemResponse.fromJson(Map<String, dynamic> json) =>
      _$PoemResponseFromJson(json);

  final String poem;
}

// ---------- 共鸣 ----------

@JsonSerializable(createToJson: false)
class ResonanceResponse {
  const ResonanceResponse({required this.resonanceCount});

  factory ResonanceResponse.fromJson(Map<String, dynamic> json) =>
      _$ResonanceResponseFromJson(json);

  /// 只回计数。不返回共鸣者，也不存在共鸣者列表接口。
  @JsonKey(name: 'resonance_count')
  final int resonanceCount;
}

@JsonSerializable()
class ResonanceRequest {
  const ResonanceRequest({this.note});

  factory ResonanceRequest.fromJson(Map<String, dynamic> json) =>
      _$ResonanceRequestFromJson(json);

  /// 可选匿名短句，≤30 字。
  final String? note;

  Map<String, dynamic> toJson() => _$ResonanceRequestToJson(this);
}

// ---------- 抄本 ----------

@JsonSerializable()
class ScripbookAddRequest {
  const ScripbookAddRequest({required this.letterId, this.note});

  factory ScripbookAddRequest.fromJson(Map<String, dynamic> json) =>
      _$ScripbookAddRequestFromJson(json);

  @JsonKey(name: 'letter_id')
  final String letterId;
  final String? note;

  Map<String, dynamic> toJson() => _$ScripbookAddRequestToJson(this);
}

// ---------- 举报（PRD §8.2）----------

@JsonSerializable()
class ReportRequest {
  const ReportRequest({required this.reason, this.detail});

  factory ReportRequest.fromJson(Map<String, dynamic> json) =>
      _$ReportRequestFromJson(json);

  /// ≤32 字的举报理由。
  final String reason;
  final String? detail;

  Map<String, dynamic> toJson() => _$ReportRequestToJson(this);
}

// ---------- 上传 ----------

@JsonSerializable(createToJson: false)
class UploadResponse {
  const UploadResponse({required this.url});

  factory UploadResponse.fromJson(Map<String, dynamic> json) =>
      _$UploadResponseFromJson(json);

  final String url;
}
