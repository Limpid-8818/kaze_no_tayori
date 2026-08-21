/// 静态目录模型：主题与心情标签。
///
/// 主题新增 = 加皮肤包，不动历史数据（红线 6）；标签只是写信时的
/// 心情速记，不是兴趣画像（红线 2：不做推荐语义）。
library;

import 'package:json_annotation/json_annotation.dart';

part 'catalog.g.dart';

@JsonSerializable(createToJson: false)
class ThemePublic {
  const ThemePublic({
    required this.id,
    required this.name,
    this.assets = const {},
    required this.isDefault,
  });

  factory ThemePublic.fromJson(Map<String, dynamic> json) =>
      _$ThemePublicFromJson(json);

  final String id;
  final String name;

  /// 资产清单（皮肤各槽可用项），结构由皮肤包自定。
  final Map<String, dynamic> assets;

  @JsonKey(name: 'is_default')
  final bool isDefault;
}

@JsonSerializable(createToJson: false)
class TagPublic {
  const TagPublic({required this.id, required this.name, required this.color});

  factory TagPublic.fromJson(Map<String, dynamic> json) =>
      _$TagPublicFromJson(json);

  final String id;
  final String name;

  /// 展示色（如 #FF6B6B）。
  final String color;
}
