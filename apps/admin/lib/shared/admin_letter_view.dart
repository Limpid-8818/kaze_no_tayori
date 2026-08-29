/// 管理端信件渲染 mapper —— API 模型 → 设计系统 LetterReading 参数。
///
/// 与 apps/app `features/reader/letter_view.dart` 同源口径（跨 app 复制，
/// 注明来源）：映射只允许发生在这里，审核页与种子信编辑预览共用。
/// 「所见即读者所见」依赖此 mapper 与读者侧逐字段一致。
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart' as natsu;

import '../../core/day_period.dart';
import '../../data/models/admin.dart';

/// 一封信的渲染视图模型：LetterReading 需要的全部内容。
class AdminLetterView {
  const AdminLetterView({
    required this.blocks,
    required this.createdAt,
    this.signature,
    this.place,
    this.weatherText,
    this.dayPeriod,
  });

  final List<natsu.LetterBlock> blocks;
  final DateTime createdAt;
  final String? signature;
  final String? place;
  final String? weatherText;

  /// 时段单字（朝/昼/夕/夜）——由落笔时刻推导。
  final String? dayPeriod;

  /// 信纸 meta 行的时间项——只到日，不读到分钟（与读者侧同口径）。
  String get timeLabel => '${createdAt.month}月${createdAt.day}日';

  static AdminLetterView from(AdminLetterDetail letter) {
    final dayPeriod = dayPeriodLabel(dayPeriodOf(letter.createdAt));
    return AdminLetterView(
      blocks: [
        for (final block in letter.blocks)
          switch (block.type) {
            'photo' => natsu.PhotoBlock(
              imageRef: block.ref ?? '',
              mood: natsu.PhotoMood.values.firstWhere(
                (m) => m.name == block.mood,
                orElse: () => natsu.PhotoMood.none,
              ),
              note: block.note,
            ),
            _ => natsu.TextBlock(block.text ?? ''),
          },
      ],
      createdAt: letter.createdAt,
      signature: letter.signature,
      place: letter.placeLabel,
      weatherText: letter.weather?.text,
      dayPeriod: dayPeriod,
    );
  }
}

/// 图片引用 → 缓存网络 ImageProvider（ref 是上传接口返回的完整 URL）。
ImageProvider adminPhotoResolver(String ref) => CachedNetworkImageProvider(ref);
