import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../tokens/natsu_tokens.dart';
import 'scaled_design.dart';

/// 夏の手紙 v2 · 邮戳 — 旅行留下的章
///
/// 地点·时间·天气的两种盖章形态：
/// - [NatsuPostmarkStyle.circular]：88 基准圆环章——纯文本三段式：
///   **地名沿内上弧排布**（真·日本消印式，按字形弧距紧凑排列）、
///   中部横排日期、下部天气。可变长度都有确定性规则：地名沿弧微缩
///   字号（有下限）、日期/天气行弦宽预算内自适应——**永不截断、
///   永不穿环**。（[emblem] 暂不参与构图，接口保留）
/// - [NatsuPostmarkStyle.horizontal]：落地戳（一行 place·date·weather，
///   上下双细线）。
///
/// 两种形态都是固定 viewBox 设计 + 整体等比缩放（[size] 只决定呈现
/// 大小，不改任何内部值）——素材像 SVG：随意缩放，视觉不变。
///
/// 珊瑚色 70% 不透明——油墨不匀的克制表达（不做纹理做旧）。
/// 邮戳是「盖上去的」，有 [seedId] 时带 ±1.5° 轻倾斜。
class Postmark extends StatelessWidget {
  const Postmark({
    super.key,
    required this.place,
    required this.date,
    this.weather,
    this.style = NatsuPostmarkStyle.circular,
    this.seedId,
    this.color = NatsuColors.coralStamp,
    this.emblem,
    this.size = 88,
  });

  final String place;

  final String date;

  final String? weather;

  final NatsuPostmarkStyle style;

  /// 种子 ID：有则 ±1.5° 轻倾斜（盖章的手抖）
  final String? seedId;

  final Color color;

  /// 中心图案（SkinMotive）；null = 纯文字环章
  final Widget? emblem;

  /// 呈现尺寸：circular = 直径；horizontal = 设计基准（字号/线距随它
  /// 等比）。默认 88 = 基准设计原大
  final double size;

  /// 圆章基准直径（viewBox）——环内一切以它为参照设计
  static const double baseSize = 88;

  /// 弧排地名的基准半径（字形中心落在环内这个圆上）
  static const double _placeRadius = 35;

  /// 弧排地名的基准字号（容量内不缩）
  static const double _placeFontBase = 13;

  /// 弧排地名的字号下限——再长的地名也不低于此（宁可弧更满）
  static const double _placeFontMin = 10;

  /// 地名弧排的字号规则（纯函数，仲裁测试锁定）：
  /// 容量 [capacity] 字以内基准字号，超出每字缩 1px 落到下限。
  /// 字号微缩换弧幅余量——永不截断
  static double arcPlaceFontSize(int charCount, {int capacity = 6}) {
    if (charCount <= capacity) return _placeFontBase;
    return math.max(_placeFontMin, _placeFontBase - (charCount - capacity));
  }

  /// 地名弧排的相邻字弧距（基准坐标 px，纯函数，测试锁定）：
  /// 字号 × 1.15 的弧距——CJK 方字的近似弧长，比直径略松一点
  /// （弧是曲线，投影会显得紧）
  static double arcPlaceStep(double fontSize) => fontSize * 1.15;

  /// 地名弧排的弧幅（度，纯函数，测试锁定）：字距积分，上限 200°
  /// （越过环心水平线太远会撞日期区）
  static double arcSpanDeg(int charCount) => math.min(
        200.0,
        arcPlaceStep(arcPlaceFontSize(charCount)) *
            charCount /
            _placeRadius *
            180 /
            math.pi,
      );

  @override
  Widget build(BuildContext context) {
    final angle = seedId == null
        ? 0.0
        : NatsuImperfection.tiltOf(seedId!) * 0.75 * math.pi / 180;

    return Transform.rotate(
      angle: angle,
      child: switch (style) {
        NatsuPostmarkStyle.circular => _circular(),
        NatsuPostmarkStyle.horizontal => _horizontal(),
      },
    );
  }

  /// 70% 不透明——油墨不匀
  Color get _ink => color.withValues(alpha: 0.7);

  /// 圆环章 — 纯文本三段式：上弧地名 / 中部横排日期 / 下部天气
  /// （[emblem] 暂不参与构图，接口保留——图样版后续再定）
  Widget _circular() {
    // 章 = 固定 viewBox 设计，等比呈现——size 只经 ScaledDesign 映射
    return ScaledDesign(
      baseWidth: baseSize,
      baseHeight: baseSize,
      width: size,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _ink, width: 1.5),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 地名弧排（真消印式：沿内上弧，字面朝外切向）——维持现状
            _arcPlace(),
            // 中部：横排日期（略低于环心——caption 的 1.54 行高把字形
            // 压在行盒上部，对齐点下移半档才是视觉居中）
            Align(
              alignment: const Alignment(0, 0.08),
              child: _chordLine(date, letterSpacing: 0.5),
            ),
            // 下部：天气（环下三分之一，短字安全区）
            if (weather != null)
              Align(
                alignment: const Alignment(0, 0.75),
                child: _chordLine(weather!),
              ),
          ],
        ),
      ),
    );
  }

  /// 环内一行 — 压在 72px 弦宽预算里，FittedBox scaleDown 兜底：
  /// 超长文本缩进而非穿环
  Widget _chordLine(String text, {double letterSpacing = 0}) => SizedBox(
        width: 72,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            style: NatsuTypography.caption.copyWith(
              color: _ink,
              fontSize: 10,
              letterSpacing: letterSpacing,
            ),
          ),
        ),
      );

  /// 地名弧排 — 拆字沿内上弧摆放，从 12 点钟向两侧展开
  Widget _arcPlace() {
    final chars = place.characters.toList();
    final fontSize = arcPlaceFontSize(chars.length);
    // 相邻字弧距 = 字号 × 1.15（紧凑——短地名不再分居两侧）；弧幅
    // 随字数积分，封顶 200°（[arcSpanDeg]）
    final stepDeg = arcPlaceStep(fontSize) / _placeRadius * 180 / math.pi;
    final spanDeg = math.min(arcSpanDeg(chars.length), stepDeg * (chars.length - 1));
    final span = spanDeg * math.pi / 180;
    final step = chars.length > 1 ? span / (chars.length - 1) : 0.0;
    // 每字角度：从 (90° + span/2) 到 (90° − span/2)——12 点钟向两侧对称展开
    final start = math.pi / 2 + span / 2;

    return SizedBox(
      width: baseSize,
      height: baseSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < chars.length; i++)
            _arcGlyph(chars[i], start - step * i, fontSize),
        ],
      ),
    );
  }

  /// 单个弧排字形 — 中心落在弧上、沿切向直立
  Widget _arcGlyph(String glyph, double theta, double fontSize) {
    final center = baseSize / 2;
    final dx = center + math.cos(theta) * _placeRadius;
    final dy = center - math.sin(theta) * _placeRadius;
    return Positioned(
      left: dx,
      top: dy,
      child: FractionalTranslation(
        // Positioned 锚在字形左上——平移半字宽高让中心落在弧上
        translation: const Offset(-0.5, -0.5),
        child: Transform.rotate(
          // 字面沿切向直立（12 点钟处旋转 0，向两侧渐倾）
          angle: math.pi / 2 - theta,
          child: Text(
            glyph,
            style: NatsuTypography.hwNote.copyWith(
              color: _ink,
              fontSize: fontSize,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  /// 落地戳 — 变宽素材（一行文字），参数化缩放（几个值 × size/88）
  Widget _horizontal() {
    final k = size / baseSize;
    final items = [
      place,
      date,
      ?weather,
    ];
    return Container(
      padding: EdgeInsets.symmetric(vertical: 5 * k, horizontal: 2 * k),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _ink, width: k),
          bottom: BorderSide(color: _ink, width: k),
        ),
      ),
      child: Text(
        items.join(' · '),
        style: NatsuTypography.meta.copyWith(
          color: _ink,
          fontSize: NatsuTypography.meta.fontSize! * k,
          letterSpacing: 1.2 * k,
        ),
      ),
    );
  }
}

enum NatsuPostmarkStyle { circular, horizontal }
