/// 管理端涉及的领域枚举（与后端 app/models/enums.py 对齐）。
///
/// 后端发小写 snake 值（如 taken_down），用 @JsonValue 显式标注。
library;

import 'package:json_annotation/json_annotation.dart';

enum LetterStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('public')
  public,
  @JsonValue('rejected')
  rejected,
  @JsonValue('taken_down')
  takenDown,
}

enum DeliveryMode {
  @JsonValue('stay')
  stay,
  @JsonValue('drift')
  drift,
}

enum ReportStatus {
  @JsonValue('open')
  open,
  @JsonValue('dismissed')
  dismissed,
  @JsonValue('actioned')
  actioned,
}

enum FeedbackCategory {
  @JsonValue('bug')
  bug,
  @JsonValue('suggestion')
  suggestion,
}

enum FeedbackStatus {
  @JsonValue('open')
  open,
  @JsonValue('resolved')
  resolved,
}
