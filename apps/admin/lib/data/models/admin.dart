/// 管理端 DTO（契约见 docs/API_CONTRACT.md §3「管理端」）。
///
/// 后端 snake_case → `fieldRename: FieldRename.snake`；特例是
/// themeSkin 内部的 camelCase 键（postmarkEmblem），单独类不走全局改名。
library;

import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';

part 'admin.g.dart';

// ---------- 信件 ----------

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class AdminLetterSummary {
  const AdminLetterSummary({
    required this.id,
    required this.status,
    required this.deliveryMode,
    this.placeLabel,
    this.lat,
    this.lon,
    this.preview,
    required this.counts,
    required this.createdAt,
  });

  factory AdminLetterSummary.fromJson(Map<String, dynamic> json) =>
      _$AdminLetterSummaryFromJson(json);

  final String id;
  final LetterStatus status;
  final DeliveryMode deliveryMode;
  final String? placeLabel;
  final double? lat;
  final double? lon;

  /// 第一个文本块的截断预览（纯照片流为 null）。
  final String? preview;
  final LetterCounts counts;
  final DateTime createdAt;
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class LetterCounts {
  const LetterCounts({
    this.read = 0,
    this.resonance = 0,
    this.voice = 0,
    this.reply = 0,
    this.saved = 0,
  });

  factory LetterCounts.fromJson(Map<String, dynamic> json) =>
      _$LetterCountsFromJson(json);

  final int read;
  final int resonance;
  final int voice;
  final int reply;
  final int saved;
}

/// blocks 的宽松联合形状：按 type 取用对应字段。
@JsonSerializable(createToJson: false)
class AdminBlock {
  const AdminBlock({this.type, this.text, this.ref, this.mood, this.note});

  factory AdminBlock.fromJson(Map<String, dynamic> json) =>
      _$AdminBlockFromJson(json);

  final String? type;
  final String? text;
  final String? ref;
  final String? mood;
  final String? note;
}

@JsonSerializable(createToJson: false)
class AdminSkin {
  const AdminSkin({this.stamp, this.postmarkEmblem, this.decor = const []});

  factory AdminSkin.fromJson(Map<String, dynamic> json) =>
      _$AdminSkinFromJson(json);

  final String? stamp;

  @JsonKey(name: 'postmarkEmblem')
  final String? postmarkEmblem;

  final List<String> decor;
}

@JsonSerializable(createToJson: false)
class AdminWeather {
  const AdminWeather({required this.text, this.tempC, this.icon});

  factory AdminWeather.fromJson(Map<String, dynamic> json) =>
      _$AdminWeatherFromJson(json);

  final String text;
  final double? tempC;
  final String? icon;
}

/// 管理端信件详情 = 读者可见形状 + status + owner_user_id（仅管理端可见）。
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class AdminLetterDetail {
  const AdminLetterDetail({
    required this.id,
    required this.blocks,
    this.poem,
    this.signature,
    this.addressee,
    required this.themeId,
    this.themeSkin,
    this.musicRef,
    this.placeLabel,
    this.weather,
    this.tags = const [],
    required this.deliveryMode,
    this.parentLetterId,
    required this.counts,
    this.lat,
    this.lon,
    required this.createdAt,
    required this.status,
    this.ownerUserId,
  });

  factory AdminLetterDetail.fromJson(Map<String, dynamic> json) =>
      _$AdminLetterDetailFromJson(json);

  final String id;
  final List<AdminBlock> blocks;
  final String? poem;
  final String? signature;
  final String? addressee;
  final String themeId;
  final AdminSkin? themeSkin;
  final Map<String, dynamic>? musicRef;
  final String? placeLabel;
  final AdminWeather? weather;
  final List<String> tags;
  final DeliveryMode deliveryMode;
  final String? parentLetterId;
  final LetterCounts counts;
  final double? lat;
  final double? lon;
  final DateTime createdAt;
  final LetterStatus status;
  final String? ownerUserId;
}

// ---------- 统计 ----------

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class AdminStats {
  const AdminStats({
    required this.lettersByStatus,
    required this.usersTotal,
    required this.letters7d,
    required this.letters30d,
    required this.pool,
    required this.todo,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) =>
      _$AdminStatsFromJson(json);

  final Map<String, int> lettersByStatus;
  final int usersTotal;

  @JsonKey(name: 'letters_7d')
  final int letters7d;

  @JsonKey(name: 'letters_30d')
  final int letters30d;
  final AdminPool pool;
  final AdminTodo todo;
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class AdminPool {
  const AdminPool({required this.driftAvailable, required this.stayActive});

  factory AdminPool.fromJson(Map<String, dynamic> json) =>
      _$AdminPoolFromJson(json);

  final int driftAvailable;
  final int stayActive;
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class AdminTodo {
  const AdminTodo({
    required this.pendingLetters,
    required this.openReports,
    required this.openFeedbacks,
  });

  factory AdminTodo.fromJson(Map<String, dynamic> json) =>
      _$AdminTodoFromJson(json);

  final int pendingLetters;
  final int openReports;
  final int openFeedbacks;
}

// ---------- 举报 / 反馈 ----------

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class AdminReportLetter {
  const AdminReportLetter({
    required this.id,
    required this.status,
    required this.deliveryMode,
    this.placeLabel,
    this.preview,
  });

  factory AdminReportLetter.fromJson(Map<String, dynamic> json) =>
      _$AdminReportLetterFromJson(json);

  final String id;
  final LetterStatus status;
  final DeliveryMode deliveryMode;
  final String? placeLabel;
  final String? preview;
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class AdminReport {
  const AdminReport({
    required this.id,
    required this.letter,
    this.reporterUserId,
    required this.reason,
    this.detail,
    required this.status,
    this.adminNote,
    this.handledAt,
    required this.createdAt,
  });

  factory AdminReport.fromJson(Map<String, dynamic> json) =>
      _$AdminReportFromJson(json);

  final String id;
  final AdminReportLetter letter;
  final String? reporterUserId;
  final String reason;
  final String? detail;
  final ReportStatus status;
  final String? adminNote;
  final DateTime? handledAt;
  final DateTime createdAt;
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class AdminFeedback {
  const AdminFeedback({
    required this.id,
    this.userId,
    required this.category,
    required this.content,
    this.appVersion,
    this.platform,
    required this.status,
    this.adminNote,
    this.handledAt,
    required this.createdAt,
  });

  factory AdminFeedback.fromJson(Map<String, dynamic> json) =>
      _$AdminFeedbackFromJson(json);

  final String id;
  final String? userId;
  final FeedbackCategory category;
  final String content;
  final String? appVersion;
  final String? platform;
  final FeedbackStatus status;
  final String? adminNote;
  final DateTime? handledAt;
  final DateTime createdAt;
}

// ---------- 分页 ----------

class AdminPage<T> {
  const AdminPage({required this.items, this.nextCursor});

  factory AdminPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonItem,
  ) {
    return AdminPage(
      items: [
        for (final item in (json['items'] as List? ?? const []))
          if (item case final Map<String, dynamic> map) fromJsonItem(map),
      ],
      nextCursor: json['next_cursor'] as String?,
    );
  }

  final List<T> items;
  final String? nextCursor;
}
