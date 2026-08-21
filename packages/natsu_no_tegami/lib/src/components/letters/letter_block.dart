import '../../tokens/natsu_tokens.dart';

/// 夏の手紙 v2 · 信件内容块 — 图文交替流的数据模型
///
/// 一封信 = 段落与照片块的有序流：照片夹在段落之间，像真实的信里
/// 夹照片。sealed 使消费点 switch 穷尽——未来加新块类型（车票/引用）
/// 编译器强制处理所有渲染点。
///
/// 序列化沿用 LetterSkin 模式：toJson 省空字段、fromJson 容忍缺失
/// （旧信向前兼容）。[PhotoBlock.imageRef] 存字符串引用不存
/// ImageProvider——图片来源由消费端 photoResolver 回调解析，lib 层
/// 与图片来源解耦。
sealed class LetterBlock {
  const LetterBlock();

  Map<String, Object?> toJson();

  static LetterBlock fromJson(Map<String, Object?> json) => switch (json['type']) {
        'text' => TextBlock.fromJson(json),
        'photo' => PhotoBlock.fromJson(json),
        _ => throw ArgumentError('未知 LetterBlock type: ${json['type']}'),
      };
}

/// 一段手写正文
final class TextBlock extends LetterBlock {
  const TextBlock(this.text);

  final String text;

  @override
  Map<String, Object?> toJson() => {'type': 'text', 'text': text};

  static TextBlock fromJson(Map<String, Object?> json) =>
      TextBlock(json['text'] as String);
}

/// 一张照片（带可选 mood 与手记）
final class PhotoBlock extends LetterBlock {
  const PhotoBlock({required this.imageRef, this.mood = PhotoMood.none, this.note});

  /// 图片引用（资产名/URL 字符串）——经 photoResolver 解析为 ImageProvider
  final String imageRef;

  /// 拍摄瞬间 mood（素/过曝/逆光/运动模糊）
  final PhotoMood mood;

  /// 手记（hwNote，照片白边底部）
  final String? note;

  @override
  Map<String, Object?> toJson() => {
        'type': 'photo',
        'ref': imageRef,
        if (mood != PhotoMood.none) 'mood': mood.name,
        if (note != null) 'note': note,
      };

  static PhotoBlock fromJson(Map<String, Object?> json) => PhotoBlock(
        imageRef: json['ref'] as String,
        mood: moodOf(json['mood'] as String?),
        note: json['note'] as String?,
      );

  static PhotoMood moodOf(String? name) => PhotoMood.values
      .firstWhere((m) => m.name == name, orElse: () => PhotoMood.none);
}

/// 流校验 — 信的图文约束在这里表达（写信流程调用）
///
/// 返回 null = 合法；返回 String = 叙事化违规句（不是错误码——
/// 给写信人看的话，如「一封信最多夹三张照片」）。渲染层不硬拦截：
/// 超图数的旧信仍可渲染，向前兼容。
String? validateLetterFlow(List<LetterBlock> blocks) {
  final photos = blocks.whereType<PhotoBlock>().length;
  if (photos > 3) return '一封信最多夹三张照片';
  if (blocks.isEmpty) return '信还没有写';
  return null;
}
