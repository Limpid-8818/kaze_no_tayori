/// 读信页的集中视图 mapper —— API 模型 → 设计系统模型的唯一映射点。
///
/// API 的 [LetterPublic] 与设计系统的 LetterBlock/LetterReading 是两套
/// 边界模型（见 docs/ARCHITECTURE.md），映射只允许发生在这里；feature
/// 页面不得各写一份。图片引用统一经 [cachedPhotoResolver] 走缓存网络图，
/// 页面里不出现散装的图片来源逻辑。
///
/// 短诗（poem）、音乐引用（musicRef）与标签在本阶段没有对应展示位——
/// mapper 直接丢弃，后续阶段在这里扩展，页面不动。宛名与皮肤有了展示
/// 位（信纸 ↔ 封筒视图切换），经 [addressee]/[skin] 供给封筒封面。
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart' as natsu;

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
    this.parentLetterId,
    this.resonanceCount = 0,
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
  final String? parentLetterId;
  final int resonanceCount;

  /// 宛名（封筒封面收信人）；null = 封面洁净。信纸态不消费，封筒
  /// 视图（页面切换）取用。
  final String? addressee;

  /// 皮肤（邮票/邮戳图案两槽）——封筒视图消费；全空 = 组件默认。
  final natsu.LetterSkin skin;

  /// 信纸 meta 行的时间项——只到日，不读到分钟。
  String get timeLabel => '${createdAt.month}月${createdAt.day}日';

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
      parentLetterId: letter.parentLetterId,
      resonanceCount: letter.counts.resonance,
      addressee: letter.addressee,
      skin: _skin(letter.themeSkin),
    );
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

  /// 「多云 26°」——没有温度就只有天气名；没有天气就是 null。
  static String? _weatherText(Weather? weather) {
    if (weather == null) return null;
    if (weather.tempC == null) return weather.text;
    return '${weather.text} ${weather.tempC!.round()}°';
  }
}

/// 图片引用 → 缓存网络 ImageProvider。photo block 的 ref 是上传接口
/// 返回的完整 URL（见 UploadsApi / 写信页 remoteUrl），直接交给缓存库。
ImageProvider cachedPhotoResolver(String ref) =>
    CachedNetworkImageProvider(ref);
