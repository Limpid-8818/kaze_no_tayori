/// 随机漂流页的集中视图 mapper —— API 模型 → 封筒封面视图模型。
///
/// 与 LetterView 同纪律：映射只允许发生在这里。封面语义只有宛名与
/// 邮戳三要素（地点·日期·天气）；短诗和正文属于拆封后的阅读器，
/// 本页不读。
library;

import 'package:natsu_no_tegami/natsu_no_tegami.dart' as natsu;

import '../../data/models/letter.dart';

/// 封筒封面的渲染视图模型。
class DriftEnvelopeView {
  const DriftEnvelopeView({
    required this.id,
    required this.seedId,
    required this.place,
    required this.date,
    this.weather,
    this.addressee,
    this.skin = const natsu.LetterSkin(),
  });

  final String id;

  /// 信 id 兼作倾斜种子——每封信的轻斜角度稳定且彼此不同。
  final String seedId;

  /// 邮戳地点。信没带 place_label 时退化为通用落款，不让邮戳空章。
  final String place;

  /// 邮戳日期（只到日）。
  final String date;

  /// 天气名（不带温度）；没有就不刻。
  final String? weather;

  /// 宛名（竖排手写）；null = 封面洁净。
  final String? addressee;

  /// 皮肤（邮票/邮戳图案两槽）；全空 = 组件默认。
  final natsu.LetterSkin skin;

  static DriftEnvelopeView from(LetterPublic letter) {
    return DriftEnvelopeView(
      id: letter.id,
      seedId: letter.id,
      place: letter.placeLabel ?? '风寄出的地方',
      date: '${letter.createdAt.month}月${letter.createdAt.day}日',
      weather: _weatherText(letter.weather),
      addressee: letter.addressee,
      skin: _skin(letter.themeSkin),
    );
  }

  static natsu.LetterSkin _skin(LetterSkin? skin) {
    if (skin == null) return const natsu.LetterSkin();
    return natsu.LetterSkin(
      stampId: skin.stamp,
      postmarkEmblemId: skin.postmarkEmblem,
    );
  }

  /// 只显示天气名，不带温度（2026-08 统一口径）；没有天气就不刻。
  static String? _weatherText(Weather? weather) {
    if (weather == null) return null;
    return weather.text;
  }
}
