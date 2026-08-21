import 'package:flutter/foundation.dart';

/// 夏の手紙 v2 · 信件皮肤搭配结果 — D20 永久绑定的对象
///
/// 各槽只存资产 ID（字符串）——const 可携带、可序列化、可跨版本兼容：
/// 信件一旦选定即永久绑定这组 ID（不因新增主题迁移/改写）；未来新增
/// 主题仅追加注册表条目（NatsuSkins），旧信的 ID 组合不受影响。
///
/// 槽位语义：邮票/邮戳/明信片单选（null = 组件默认），装饰可多枚。
/// 全空 = 全默认（不携带皮肤的信）。
@immutable
final class LetterSkin {
  const LetterSkin({
    this.stampId,
    this.postmarkEmblemId,
    this.decorIds = const [],
    this.postcardId,
  });

  /// 邮票资产 ID（SkinSlot.stamp）→ StampPiece.motive
  final String? stampId;

  /// 邮戳中心图案资产 ID（SkinSlot.postmark）→ Postmark.emblem
  final String? postmarkEmblemId;

  /// 装饰资产 ID 列表（SkinSlot.decor，可多枚）→ SkinDecor
  final List<String> decorIds;

  /// 明信片底图资产 ID — 槽位保留，待「信」的形态确定（本期恒 null）
  final String? postcardId;

  /// 序列化（信件 JSON 的 `skin` 字段）；空槽省字段
  Map<String, Object?> toJson() => {
    if (stampId != null) 'stamp': stampId,
    if (postmarkEmblemId != null) 'postmarkEmblem': postmarkEmblemId,
    if (decorIds.isNotEmpty) 'decor': decorIds,
    if (postcardId != null) 'postcard': postcardId,
  };

  factory LetterSkin.fromJson(Map<String, Object?> json) => LetterSkin(
    stampId: json['stamp'] as String?,
    postmarkEmblemId: json['postmarkEmblem'] as String?,
    decorIds: (json['decor'] as List<Object?>? ?? const [])
        .map((e) => e as String)
        .toList(),
    postcardId: json['postcard'] as String?,
  );
}
