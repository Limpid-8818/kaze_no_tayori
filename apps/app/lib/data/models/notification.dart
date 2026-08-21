/// 回信告知模型（PRD 6.5）。
///
/// 原作者**不是回信的收件人**，通知只是「获知」：没有回信正文、
/// 没有回信作者，点击后跳转的是公开回信本身。
library;

import 'package:json_annotation/json_annotation.dart';

part 'notification.g.dart';

/// 通知类型。当前只有回信一种；契约扩值时 $enumDecode 会抛错——
/// 有意的 fail-fast，红了说明该同步契约了。
enum NotificationType {
  @JsonValue('reply')
  reply,
}

@JsonSerializable(createToJson: false)
class NotificationPublic {
  const NotificationPublic({
    required this.id,
    required this.type,
    required this.letterId,
    required this.parentLetterId,
    this.parentPlaceLabel,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationPublic.fromJson(Map<String, dynamic> json) =>
      _$NotificationPublicFromJson(json);

  final String id;
  final NotificationType type;

  /// 触发通知的那封信（回信本体）。
  @JsonKey(name: 'letter_id')
  final String letterId;

  /// 自己的原信。
  @JsonKey(name: 'parent_letter_id')
  final String parentLetterId;

  @JsonKey(name: 'parent_place_label')
  final String? parentPlaceLabel;

  @JsonKey(name: 'is_read')
  final bool isRead;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;
}
