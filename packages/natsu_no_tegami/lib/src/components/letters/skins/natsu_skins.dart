import 'package:flutter/material.dart';

import '../../../tokens/natsu_tokens.dart';
import 'skin_assets.dart';
import 'skin_painters.dart';

/// 夏の手紙 v2 · 皮肤资产注册表 — 「Theme · 夏」资产库
///
/// 新增主题/资产 = 在 [all] 追加条目，不改任何消费端（theme 解耦）。
/// 邮戳槽全 coralStamp（盖章油墨统一）；装饰槽禁珊瑚（配给制——
/// 珊瑚只属于邮戳/邮票/旅行标记，装饰不承载旅行语义）。
abstract final class NatsuSkins {
  static const List<NatsuSkinAsset> all = [
    // ---- 邮票槽 -------------------------------------------------------------
    NatsuSkinAsset(
      id: 'stamp.sea-01',
      slot: SkinSlot.stamp,
      labelJa: '海',
      ink: NatsuColors.skyBlue,
      aspectRatio: 0.8,
      painter: SeaStampPainter(NatsuColors.skyBlue),
    ),
    NatsuSkinAsset(
      id: 'stamp.rain-02',
      slot: SkinSlot.stamp,
      labelJa: '雨',
      ink: NatsuColors.inkSoft,
      aspectRatio: 0.8,
      painter: RainStampPainter(NatsuColors.inkSoft),
    ),
    NatsuSkinAsset(
      id: 'stamp.dusk-03',
      slot: SkinSlot.stamp,
      labelJa: '夕焼',
      ink: NatsuColors.coralStamp,
      aspectRatio: 0.8,
      painter: DuskStampPainter(NatsuColors.coralStamp),
    ),
    NatsuSkinAsset(
      id: 'stamp.night-04',
      slot: SkinSlot.stamp,
      labelJa: '夜風',
      ink: NatsuColors.inkBlue,
      aspectRatio: 0.8,
      painter: NightWindStampPainter(NatsuColors.inkBlue),
    ),
    // ---- 邮戳槽（中心图案）--------------------------------------------------
    NatsuSkinAsset(
      id: 'postmark.cicada-01',
      slot: SkinSlot.postmark,
      labelJa: '蝉',
      ink: NatsuColors.coralStamp,
      aspectRatio: 1.0,
      painter: CicadaEmblemPainter(NatsuColors.coralStamp),
    ),
    NatsuSkinAsset(
      id: 'postmark.tram-02',
      slot: SkinSlot.postmark,
      labelJa: '電車',
      ink: NatsuColors.coralStamp,
      aspectRatio: 1.0,
      painter: TramEmblemPainter(NatsuColors.coralStamp),
    ),
    NatsuSkinAsset(
      id: 'postmark.fireworks-03',
      slot: SkinSlot.postmark,
      labelJa: '花火',
      ink: NatsuColors.coralStamp,
      aspectRatio: 1.0,
      painter: FireworksEmblemPainter(NatsuColors.coralStamp),
    ),
    NatsuSkinAsset(
      id: 'postmark.wave-04',
      slot: SkinSlot.postmark,
      labelJa: '波',
      ink: NatsuColors.coralStamp,
      aspectRatio: 1.0,
      painter: WaveEmblemPainter(NatsuColors.coralStamp),
    ),
    // ---- 装饰槽（贴纸语义）--------------------------------------------------
    NatsuSkinAsset(
      id: 'decor.shell-01',
      slot: SkinSlot.decor,
      labelJa: '貝殻',
      ink: NatsuColors.leaf,
      aspectRatio: 0.85,
      painter: ShellDecorPainter(NatsuColors.leaf),
    ),
    NatsuSkinAsset(
      id: 'decor.hanabi-02',
      slot: SkinSlot.decor,
      labelJa: '線香花火',
      ink: NatsuColors.sunlightYellow,
      aspectRatio: 0.7,
      painter: SparklerDecorPainter(NatsuColors.sunlightYellow),
    ),
    NatsuSkinAsset(
      id: 'decor.leaf-03',
      slot: SkinSlot.decor,
      labelJa: '葉',
      ink: NatsuColors.leaf,
      aspectRatio: 0.62,
      painter: LeafDecorPainter(NatsuColors.leaf),
    ),
    // ---- 明信片槽：保留位，待「信」的形态确定 --------------------------------
  ];

  static final Map<String, NatsuSkinAsset> _index = {
    for (final a in all) a.id: a,
  };

  /// id → 资产；未注册 id 返回 null（消费端自行回落默认）
  static NatsuSkinAsset? byId(String id) => _index[id];

  /// 按槽过滤（注册表有序；postcard 当前为空）
  static Iterable<NatsuSkinAsset> bySlot(SkinSlot slot) =>
      all.where((a) => a.slot == slot);
}

/// 按资产 ID 渲染图案的便捷组件 — StampPiece.motive / Postmark.emblem 的桥
///
/// ```dart
/// StampPiece(seedId: 'letter-01', motive: SkinMotive('stamp.sea-01'))
/// Postmark(place: '鎌倉', date: '2026.08.20', emblem: SkinMotive('postmark.wave-04'))
/// ```
class SkinMotive extends StatelessWidget {
  const SkinMotive(this.assetId, {super.key});

  /// 序列化稳定的资产 ID（如 `stamp.sea-01`）
  final String assetId;

  @override
  Widget build(BuildContext context) {
    final asset = NatsuSkins.byId(assetId);
    if (asset == null) return const SizedBox.shrink();
    return CustomPaint(painter: asset.painter, size: Size.infinite);
  }
}
