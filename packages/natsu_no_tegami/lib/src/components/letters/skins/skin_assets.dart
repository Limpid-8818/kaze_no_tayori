import 'package:flutter/material.dart';

/// 夏の手紙 v2 · 皮肤资产类型 — 分类搭配的轴与格子
///
/// 主题皮肤框架（Theme · 夏）：资产按类别（[SkinSlot]）分轴独立挑选，
/// 不做成套——意象（蝉/海/雨/電車/夕焼/花火/夜風）只是资产的设计语源
/// （命名与图案出处），不是搭配单位。信件永久绑定的是搭配结果
/// （各槽资产 ID，见 LetterSkin），theme 字段与之解耦。
///
/// 所有资产图案是纯几何 CustomPainter（零依赖纪律），用色只来自
/// NatsuColors——coralStamp 配给制：仅邮戳/邮票槽可用，装饰槽禁珊瑚。
enum SkinSlot { postmark, stamp, decor, postcard }

extension SkinSlotX on SkinSlot {
  /// 分组短名（画廊分组标题用）
  String get labelJa => switch (this) {
        SkinSlot.postmark => '邮戳',
        SkinSlot.stamp => '邮票',
        SkinSlot.decor => '装饰',
        SkinSlot.postcard => '明信片',
      };

  String get labelEn => switch (this) {
        SkinSlot.postmark => 'POSTMARK',
        SkinSlot.stamp => 'STAMP',
        SkinSlot.decor => 'DECOR',
        SkinSlot.postcard => 'POSTCARD',
      };
}

/// 一个皮肤资产 — 无状态 const 数据 + painter
///
/// [aspectRatio] 为宽/高，消费端据此定尺寸（[SkinDecor]）；邮票槽票面
/// 由 StampPiece 定形（约 0.8），此字段对它仅作画廊预览比例。
final class NatsuSkinAsset {
  const NatsuSkinAsset({
    required this.id,
    required this.slot,
    required this.labelJa,
    required this.ink,
    required this.aspectRatio,
    required this.painter,
  });

  /// 序列化稳定 ID，规范 `<slot>.<motive>-<序号>`（如 `stamp.sea-01`）。
  /// 信件持久化的是 ID 组合，未来新增主题仅追加注册表条目。
  final String id;

  final SkinSlot slot;

  /// 意象短名（日文，画廊 caption）
  final String labelJa;

  /// 资产主色 — 只能来自 NatsuColors；coralStamp 配给见类注释
  final Color ink;

  final double aspectRatio;

  /// 纯几何 CustomPainter，const 实例，`shouldRepaint` 恒 false
  final CustomPainter painter;
}
