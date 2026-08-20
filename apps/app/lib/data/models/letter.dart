/// 信件模型。字段名与后端 Pydantic schema **严格同名**（见 docs/API_CONTRACT.md）。
///
/// 匿名铁律在客户端的体现：[LetterPublic] 没有作者字段，也没有精确坐标——
/// 服务端不给，客户端就没有渲染它的可能。**不要为了「方便」加回来。**
///
/// 用 json_serializable 而非 freezed：见 pubspec.yaml 里的版本冲突说明。
/// 不可变性靠 final 字段自律。
library;

import 'package:json_annotation/json_annotation.dart';

part 'letter.g.dart';

/// 投递方式。两者都是一等公民。
enum DeliveryMode {
  /// 留在这里：锚定位置，后来者就地发掘
  @JsonValue('stay')
  stay,

  /// 投递出去：入随机漂流池
  @JsonValue('drift')
  drift,
}

/// 信件状态。只有 public 参与漂流抽取与就地发掘。
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

/// 引用式音乐：只有三个字符串。不生成、不上传、不外链。
@JsonSerializable()
class MusicRef {
  const MusicRef({
    required this.album,
    required this.song,
    required this.lyrics,
  });

  factory MusicRef.fromJson(Map<String, dynamic> json) =>
      _$MusicRefFromJson(json);

  final String album;
  final String song;
  final String lyrics;

  Map<String, dynamic> toJson() => _$MusicRefToJson(this);
}

/// 落点天气，「此情此景」的锚点之一。取不到就是 null，不影响写信。
@JsonSerializable()
class Weather {
  const Weather({required this.text, this.tempC, this.icon});

  factory Weather.fromJson(Map<String, dynamic> json) =>
      _$WeatherFromJson(json);

  final String text;
  @JsonKey(name: 'temp_c')
  final double? tempC;
  final String? icon;

  Map<String, dynamic> toJson() => _$WeatherToJson(this);
}

/// 叙事计数。**只有这 5 个**，不是点赞数、不参与跨信排行。
@JsonSerializable()
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

  /// 「已被 N 个陌生人接住」——这是共鸣，不是赞。
  final int resonance;
  final int voice;
  final int reply;
  final int saved;

  Map<String, dynamic> toJson() => _$LetterCountsToJson(this);
}

/// 对外信件。**没有作者字段，没有精确坐标。**
@JsonSerializable()
class LetterPublic {
  const LetterPublic({
    required this.id,
    required this.content,
    required this.theme,
    required this.deliveryMode,
    required this.counts,
    required this.createdAt,
    this.poem,
    this.images = const [],
    this.musicRef,
    this.placeLabel,
    this.weather,
    this.tags = const [],
    this.parentLetterId,
  });

  factory LetterPublic.fromJson(Map<String, dynamic> json) =>
      _$LetterPublicFromJson(json);

  final String id;
  final String content;

  /// AI 短诗，≤4 行。可为 null（AI 关闭或用户没采纳）。
  final String? poem;
  final List<String> images;
  final String theme;
  @JsonKey(name: 'music_ref')
  final MusicRef? musicRef;

  /// 只有地点名，没有坐标——城市级足够承载「此情此景」。
  @JsonKey(name: 'place_label')
  final String? placeLabel;
  final Weather? weather;
  final List<String> tags;
  @JsonKey(name: 'delivery_mode')
  final DeliveryMode deliveryMode;

  /// 回信溯源。非空说明这封信是对另一封的回应（但它是独立作品）。
  @JsonKey(name: 'parent_letter_id')
  final String? parentLetterId;
  final LetterCounts counts;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Map<String, dynamic> toJson() => _$LetterPublicToJson(this);
}
