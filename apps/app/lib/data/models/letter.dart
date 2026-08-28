/// 信件模型。字段名与后端 Pydantic schema **严格同名**（见 docs/API_CONTRACT.md）。
///
/// 匿名铁律在客户端的体现：[LetterPublic] 没有作者字段，也没有精确坐标——
/// 服务端不给，客户端就没有渲染它的可能。**不要为了「方便」加回来。
///
/// 用 json_serializable 而非 freezed：见 pubspec.yaml 里的版本冲突说明。
/// 不可变性靠 final 字段自律。
library;

import 'package:json_annotation/json_annotation.dart';

part 'letter.g.dart';

// ---------- 投递与状态 ----------

/// 投递方式。两者都是一等公民。
enum DeliveryMode {
  @JsonValue('stay')
  stay,

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

// ---------- 图文交替流（PRD 6.1 · blocks）----------

/// 照片 mood——按下快门的那一瞬间。
enum PhotoMood {
  @JsonValue('none')
  none,
  @JsonValue('overexposed')
  overexposed,
  @JsonValue('backlit')
  backlit,
  @JsonValue('motion')
  motion,
}

/// 单块——正文段或照片块。
///
/// 可空字段一律 `includeIfNull: false`：后端 Pydantic 的 PhotoBlock.mood
/// 是必填 str，序列化出 `"mood": null` 会被拒成 422；旧信的反序列化
/// （fromJson 容忍缺失）不受影响。
@JsonSerializable()
class LetterBlock {
  const LetterBlock({
    required this.type,
    this.text,
    this.ref,
    this.mood,
    this.note,
  });

  factory LetterBlock.fromJson(Map<String, dynamic> json) =>
      _$LetterBlockFromJson(json);

  final String type; // 'text' | 'photo'
  @JsonKey(includeIfNull: false)
  final String? text;
  @JsonKey(includeIfNull: false)
  final String? ref;
  @JsonKey(includeIfNull: false)
  final PhotoMood? mood;
  @JsonKey(includeIfNull: false)
  final String? note;

  Map<String, dynamic> toJson() => _$LetterBlockToJson(this);
}

// ---------- 皮肤搭配（PRD 6.9 · theme_skin）----------

/// 信件皮肤搭配——各槽只存资产 ID 字符串。
///
/// 空槽 = 不携带该层皮肤，渲染层用默认值。**全空 = 全默认**（不携带皮肤的信）。
@JsonSerializable()
class LetterSkin {
  const LetterSkin({
    this.stamp,
    this.postmarkEmblem,
    this.decor = const [],
    this.postcard,
  });

  factory LetterSkin.fromJson(Map<String, dynamic> json) =>
      _$LetterSkinFromJson(json);

  final String? stamp;
  @JsonKey(name: 'postmarkEmblem')
  final String? postmarkEmblem;
  final List<String> decor;
  final String? postcard;

  Map<String, dynamic> toJson() => _$LetterSkinToJson(this);
}

// ---------- 引用式音乐（PRD 6.7）----------

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

// ---------- 天气（PRD 6.1 · 落点天气）----------

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

// ---------- 叙事计数（PRD §7.4）----------

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

// ---------- 对外信件 ----------

/// 对外信件。**没有作者字段，没有精确坐标。**
@JsonSerializable()
class LetterPublic {
  const LetterPublic({
    required this.id,
    required this.blocks,
    required this.themeId,
    required this.deliveryMode,
    required this.counts,
    required this.createdAt,
    this.poem,
    this.signature,
    this.addressee,
    this.themeSkin,
    this.musicRef,
    this.placeLabel,
    this.weather,
    this.tags = const [],
    this.parentLetterId,
    this.meResonated = false,
  });

  factory LetterPublic.fromJson(Map<String, dynamic> json) =>
      _$LetterPublicFromJson(json);

  final String id;
  final List<LetterBlock> blocks;

  /// AI 短诗，≤4 行。可为 null（AI 关闭或用户没采纳）。
  final String? poem;

  /// 信尾署名，写信人自填（可空 = 不署名）。内容物，非作者标识。
  final String? signature;

  /// 宛名（封筒封面收信人），写信人自填。内容物，非读者标识。
  final String? addressee;

  /// 基础主题 ID（如 "natsu"），指向 themes 表。
  @JsonKey(name: 'theme_id')
  final String themeId;

  /// 皮肤搭配（可选，不传则全默认）。
  @JsonKey(name: 'theme_skin')
  final LetterSkin? themeSkin;

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

  /// 当前读者是否已共鸣过（一次性）。仅详情接口按登录用户下发，
  /// 列表接口不计算恒为 false——以读信页重新拉取的详情为准。
  @JsonKey(name: 'me_resonated')
  final bool meResonated;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Map<String, dynamic> toJson() => _$LetterPublicToJson(this);
}

// ---------- 本人视角 ----------

/// 本人视角，仅 /v1/me/* 路径返回。
///
/// 比 LetterPublic 多出状态与自己的落点坐标。**仍不含 owner_user_id**——
/// 自己不需要看自己的 id。
@JsonSerializable()
class LetterOwned extends LetterPublic {
  const LetterOwned({
    required super.id,
    required super.blocks,
    required super.themeId,
    required super.deliveryMode,
    required super.counts,
    required super.createdAt,
    super.poem,
    super.signature,
    super.addressee,
    super.themeSkin,
    super.musicRef,
    super.placeLabel,
    super.weather,
    super.tags,
    super.parentLetterId,
    required this.status,
    this.lat,
    this.lon,
  });

  factory LetterOwned.fromJson(Map<String, dynamic> json) =>
      _$LetterOwnedFromJson(json);

  final LetterStatus status;
  final double? lat;
  final double? lon;

  @override
  Map<String, dynamic> toJson() => _$LetterOwnedToJson(this);
}

// ---------- 写信请求 ----------

@JsonSerializable()
class LetterCreateRequest {
  const LetterCreateRequest({
    required this.blocks,
    this.poem,
    this.signature,
    this.addressee,
    required this.themeId,
    this.themeSkin,
    this.musicRef,
    this.tags = const [],
    required this.deliveryMode,
    this.lat,
    this.lon,
    this.placeLabel,
    this.weather,
  });

  factory LetterCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$LetterCreateRequestFromJson(json);

  final List<LetterBlock> blocks;
  final String? poem;

  /// 信尾署名（可空 = 不署名）。内容物，非作者标识。
  final String? signature;

  /// 宛名（封筒封面收信人，可空）。内容物，非读者标识。
  final String? addressee;
  @JsonKey(name: 'theme_id')
  final String themeId;
  @JsonKey(name: 'theme_skin')
  final LetterSkin? themeSkin;
  @JsonKey(name: 'music_ref')
  final MusicRef? musicRef;
  final List<String> tags;
  @JsonKey(name: 'delivery_mode')
  final DeliveryMode deliveryMode;
  final double? lat;
  final double? lon;
  @JsonKey(name: 'place_label')
  final String? placeLabel;
  final Weather? weather;

  Map<String, dynamic> toJson() => _$LetterCreateRequestToJson(this);
}
