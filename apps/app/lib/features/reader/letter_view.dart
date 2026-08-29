/// 读信页的集中视图 mapper —— API 模型 → 设计系统模型的唯一映射点。
///
/// API 的 [LetterPublic] 与设计系统的 LetterBlock/LetterReading 是两套
/// 边界模型（见 docs/ARCHITECTURE.md），映射只允许发生在这里；feature
/// 页面不得各写一份。图片引用统一经 [cachedPhotoResolver] 走缓存网络图，
/// 页面里不出现散装的图片来源逻辑。
///
/// 短诗与叙事计数也在这里收口，读信页与导出图消费同一个 [LetterView]，
/// 避免两套展示口径。音乐引用与标签暂时没有对应展示位。
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart' as natsu;

import '../../app/theme.dart' show KazeSky;
import '../../core/day_period.dart';
import '../../data/models/letter.dart';

/// 一封信的渲染视图模型：LetterReading 需要的全部内容。
class LetterView {
  const LetterView({
    required this.id,
    required this.blocks,
    required this.createdAt,
    this.signature,
    this.place,
    this.weatherText,
    this.weatherIcon,
    this.poem,
    this.parentLetterId,
    this.readCount = 0,
    this.resonanceCount = 0,
    this.voiceCount = 0,
    this.replyCount = 0,
    this.resonated = false,
    this.addressee,
    this.skin = const natsu.LetterSkin(),
  });

  final String id;
  final List<natsu.LetterBlock> blocks;
  final DateTime createdAt;
  final String? signature;
  final String? place;
  final String? weatherText;

  /// 天气归类档（sunny/cloudy/rainy）—— 读信页天空以信携带的天色为准；
  /// null = 信没带天气（背景回退默认昼·晴）。
  final String? weatherIcon;
  final String? poem;
  final String? parentLetterId;
  final int readCount;
  final int resonanceCount;
  final int voiceCount;
  final int replyCount;

  /// 当前读者已共鸣过（详情接口 me_resonated 下发）——重进这封信时章
  /// 常亮，不再反直觉地熄着；列表来源的模型恒 false，以详情为准。
  final bool resonated;

  /// 宛名（封筒封面收信人）；null = 封面洁净。信纸态不消费，封筒
  /// 视图（页面切换）取用。
  final String? addressee;

  /// 皮肤（邮票/邮戳图案两槽）——封筒视图消费；全空 = 组件默认。
  final natsu.LetterSkin skin;

  /// PRD 的互动口径 = 共鸣 + 留声；抄本是个人行为，不进入公开互动。
  int get interactionCount => resonanceCount + voiceCount;

  LetterView copyWith({
    int? readCount,
    int? resonanceCount,
    int? voiceCount,
    int? replyCount,
    bool? resonated,
  }) {
    return LetterView(
      id: id,
      blocks: blocks,
      createdAt: createdAt,
      signature: signature,
      place: place,
      weatherText: weatherText,
      weatherIcon: weatherIcon,
      poem: poem,
      parentLetterId: parentLetterId,
      readCount: readCount ?? this.readCount,
      resonanceCount: resonanceCount ?? this.resonanceCount,
      voiceCount: voiceCount ?? this.voiceCount,
      replyCount: replyCount ?? this.replyCount,
      resonated: resonated ?? this.resonated,
      addressee: addressee,
      skin: skin,
    );
  }

  /// 信纸 meta 行的时间项——只到日，不读到分钟。
  String get timeLabel => '${createdAt.month}月${createdAt.day}日';

  /// 信纸 meta 行的时段项（朝/昼/夕/夜）——由落笔时刻推导，永远有值。
  /// 四段口径（地点·日期·时段·天气）与写信页预览一致。
  String get dayPeriod => dayPeriodLabel(dayPeriodOf(createdAt));

  static LetterView from(LetterPublic letter) {
    return LetterView(
      id: letter.id,
      blocks: [
        for (final block in letter.blocks)
          switch (block.type) {
            'text' => natsu.TextBlock(block.text ?? ''),
            'photo' => natsu.PhotoBlock(
              imageRef: block.ref ?? '',
              mood: natsu.PhotoMood.values.firstWhere(
                (m) => m.name == block.mood?.name,
                orElse: () => natsu.PhotoMood.none,
              ),
              note: block.note,
            ),
            _ => natsu.TextBlock(''),
          },
      ],
      createdAt: letter.createdAt,
      signature: letter.signature,
      place: letter.placeLabel,
      weatherText: _weatherText(letter.weather),
      weatherIcon: letter.weather?.icon,
      poem: _nonBlank(letter.poem),
      parentLetterId: letter.parentLetterId,
      readCount: letter.counts.read,
      resonanceCount: letter.counts.resonance,
      voiceCount: letter.counts.voice,
      replyCount: letter.counts.reply,
      resonated: letter.meResonated,
      addressee: letter.addressee,
      skin: _skin(letter.themeSkin),
    );
  }

  static String? _nonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// API 皮肤 → 组件库皮肤（stamp/postmark 两槽；decor 属于信纸不贴
  /// 封筒）。与漂流页 DriftEnvelopeView 的同款转换——封筒封面语义一致。
  static natsu.LetterSkin _skin(LetterSkin? skin) {
    if (skin == null) return const natsu.LetterSkin();
    return natsu.LetterSkin(
      stampId: skin.stamp,
      postmarkEmblemId: skin.postmarkEmblem,
    );
  }

  /// 只显示天气名，不带温度（2026-08 统一口径）；没有天气就是 null。
  static String? _weatherText(Weather? weather) {
    if (weather == null) return null;
    return weather.text;
  }
}

/// 图片引用 → 缓存网络 ImageProvider。photo block 的 ref 是上传接口
/// 返回的完整 URL（见 UploadsApi / 写信页 remoteUrl），直接交给缓存库。
ImageProvider cachedPhotoResolver(String ref) =>
    CachedNetworkImageProvider(ref);

/// 这封信的天空 — 读信页背景与导出图背景共用的唯一天色口径：
/// 信携带的天气 × 信落笔时刻的时段查表（「环境光随信」）；没带天气
/// 或还没读进来 → 默认昼·晴。显式取用后不吃全局天色联动。
Gradient skyOfLetter(LetterView? view) {
  if (view == null || view.weatherIcon == null) {
    return KazeSky.defaultGradient;
  }
  return KazeSky.of(
    KazeSky.fromIcon(view.weatherIcon),
    KazeSky.daypartOf(view.createdAt),
  );
}
