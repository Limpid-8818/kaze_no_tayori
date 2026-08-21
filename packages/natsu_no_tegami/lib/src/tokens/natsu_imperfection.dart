import 'dart:math' as math;
import 'dart:ui' show Offset;

/// 夏の手紙 v2 · Controlled Imperfection 令牌 — 受控的不完美
///
/// 青春感来自一点点不完美：照片轻歪、邮票不齐、日期贴边。但三条硬规则
/// 让它是设计而不是 bug：
/// 1. **确定性**：不完美由内容 ID 派生（FNV-1a 哈希），同一内容永远歪
///    同一个角度——绝不做每帧随机。
/// 2. **配给制**：不完美只属于内容物（照片/车票/邮票/信纸这些「桌上的
///    东西」）；UI 骨架（按钮/输入框/导航/网格）永远严格对齐。
///    Grid 是现代的，Content 是不完美的。
/// 3. **量化**：倾斜 ±1.5°–2°、偏移 ±4–6px，可感知但不妨碍阅读。
abstract final class NatsuImperfection {
  /// 最大倾斜（度，绝对值）
  static const double tiltMax = 2.0;

  /// 最小倾斜——低于此幅度等于假对齐，不如不歪
  static const double tiltMin = 1.5;

  /// 最大偏移（px）
  static const double offsetMax = 6.0;

  /// 最小偏移
  static const double offsetMin = 4.0;

  /// 内容 ID → [0, 1) 的确定性种子（FNV-1a 32-bit）
  static double seedOf(String id) {
    var h = 0x811c9dc5;
    for (final c in id.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return (h % 10000) / 10000;
  }

  /// 内容 ID → 倾斜角（度，带符号）。幅度 ∈ [tiltMin, tiltMax]，
  /// 符号由种子奇偶决定——避开 0 附近（防「假对齐」）。
  static double tiltOf(String id) {
    final seed = seedOf(id);
    final magnitude = tiltMin + seed * (tiltMax - tiltMin);
    final sign = (id.hashCode ^ id.length) & 1 == 0 ? 1.0 : -1.0;
    return magnitude * sign;
  }

  /// 内容 ID → 偏移。x/y 由 id 派生的独立种子决定，各自 ∈ ±[offsetMin, offsetMax]。
  static Offset offsetOf(String id) {
    final sx = seedOf('$id/x');
    final sy = seedOf('$id/y');
    double axis(double s, String tag) {
      final magnitude = offsetMin + s * (offsetMax - offsetMin);
      final sign = (tag.codeUnitAt(0) + id.length) & 1 == 0 ? 1.0 : -1.0;
      return magnitude * sign;
    }

    return Offset(axis(sx, '$id/x'), axis(sy, '$id/y'));
  }

  /// 0°–360° 的确定角度（颗粒/光带布局用）
  static double angleOf(String id) => seedOf(id) * 360 * math.pi / 180;
}
