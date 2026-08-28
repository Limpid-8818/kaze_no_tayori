import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../tokens/natsu_tokens.dart';

/// 夏の手紙 v2 · 共鸣 — 一键 ✦，一次性的「我也曾有过这样的时刻」
///
/// 纪律：不是点赞——无取消路径、不展示谁、计数排成句子不是指标。
/// [resonated] 与 [count] 都由父层持有（受控组件，与 NatsuButton 同哲学）：
/// App 层在 [onResonate] 回调里落库并 setState；组件侧在 resonated 后
/// 忽略后续 tap，防父层状态滞后导致双击双计数。
///
/// 三态：
/// - 未共鸣可按：✦ inkSoft（安静等待）+「共鸣」行动字 + 句子（淡墨）
/// - 已共鸣：✦ coralStamp（同感者留下的章）+ 句子——色彩变化本身就是
///   「留下了痕迹」；✦ 是装饰符号不承载文字，文字永远墨蓝系（珊瑚配给制）
/// - 禁用（onResonate == null）：✦/行动字降级，句子正常显示（事实陈述不降级）
///
/// 落章动效：resonated false→true 的瞬间，✦ 以 0.6→1.15→1 弹跳 +
/// -8°→0° 旋正落定（NatsuMotion.medium + easing——落章是「按下的瞬间事」）。
class NatsuResonance extends StatefulWidget {
  const NatsuResonance({
    super.key,
    required this.count,
    required this.onResonate,
    this.resonated = false,
  });

  /// 已共鸣人数（句子式计数的数据源）。
  final int count;

  /// 共鸣回调；null = 禁用（这封信不可共鸣）。
  final VoidCallback? onResonate;

  /// 当前读者是否已共鸣（一次性，父层持久化）。
  final bool resonated;

  /// 句子式共鸣计数 — 「N 个陌生人也曾有过这样的时刻」。
  /// 零计数不排「0 个」（计数是叙事不是指标）：『它还在等第一个同感的人』。
  static String sentence(int count) =>
      count <= 0 ? '它还在等第一个同感的人' : '${compactCount(count)} 个陌生人也曾有过这样的时刻';

  /// 大数缩写：万位起折算「X.X万」、亿位起「X.X亿」（尾零与点省略），
  /// 其余保持完整数字。句子是叙事不是指标，2147483647 排进句子里会
  /// 把整行撑爆；缩写保证句子长度有上界。
  static String compactCount(int count) {
    if (count < 10000) return '$count';
    late final double unit;
    late final String suffix;
    if (count >= 100000000) {
      unit = count / 100000000;
      suffix = '亿';
    } else {
      unit = count / 10000;
      suffix = '万';
    }
    final text = unit.toStringAsFixed(1);
    final trimmed = text.endsWith('.0')
        ? text.substring(0, text.length - 2)
        : text;
    return '$trimmed$suffix';
  }

  @override
  State<NatsuResonance> createState() => _NatsuResonanceState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('count', count));
    properties.add(
      FlagProperty(
        'resonated',
        value: resonated,
        ifTrue: '已共鸣',
        ifFalse: '未共鸣',
      ),
    );
    properties.add(
      FlagProperty(
        'hasOnResonate',
        value: onResonate != null,
        ifTrue: '可共鸣',
        ifFalse: '禁用',
      ),
    );
  }
}

class _NatsuResonanceState extends State<NatsuResonance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stamp = AnimationController(
    vsync: this,
    duration: NatsuMotion.medium,
  );

  bool _hovered = false;
  bool _pressed = false;

  @override
  void didUpdateWidget(NatsuResonance old) {
    super.didUpdateWidget(old);
    // 落章只认 false→true 的那一瞬（父层重建已共鸣状态时不重放）
    if (widget.resonated && !old.resonated) {
      _stamp.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _stamp.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onResonate != null && !widget.resonated;

  @override
  Widget build(BuildContext context) {
    final canInteract = widget.onResonate != null;
    final sparkleColor = !canInteract
        ? NatsuColors.disabledContent
        : widget.resonated
        ? NatsuColors.coralStamp
        : NatsuColors.inkSoft;

    // 交互覆盖层（ghost 手法，与 NatsuButton 同语言）；仅未共鸣可按
    final Color overlay;
    if (!_enabled) {
      overlay = Colors.transparent;
    } else if (_pressed) {
      overlay = NatsuColors.pressedOverlay;
    } else if (_hovered) {
      overlay = NatsuColors.hoverOverlay;
    } else {
      overlay = Colors.transparent;
    }

    // 落章曲线：0→1 的 controller 经 easing，前段冲过 1（1.15）再落回。
    // 用 TweenSequence 分两段：冲章（0.6→1.15）与落定（1.15→1.0）。
    final curved = CurvedAnimation(parent: _stamp, curve: NatsuMotion.easing);
    final scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.6,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(curved);
    // RotationTransition 收 turns（圈），-8° → 0° 换算成圈
    final rotationTurns = Tween(begin: -8.0 / 360, end: 0.0).animate(curved);

    return FocusableActionDetector(
      mouseCursor: _enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowHoverHighlight: _enabled
          ? (h) => setState(() => _hovered = h)
          : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        // 一次性：共鸣后即使回调仍在也忽略 tap（防双击双计数）
        onTap: _enabled ? widget.onResonate : null,
        child: AnimatedContainer(
          duration: NatsuMotion.short,
          curve: NatsuMotion.easing,
          padding: const EdgeInsets.symmetric(
            horizontal: NatsuSpacing.md,
            vertical: NatsuSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: overlay,
            borderRadius: BorderRadius.circular(NatsuRadius.card),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 未落章时 ✦ 静止在 scale 1 / 0°（controller 0）；落章动画驱动。
              // 星形用 Painter 描不走文字度量：固定 18×18 盒子进 Row 按
              // 包围盒居中，与句子基线天然无高低差（✦ 曾是文本符号，
              // 手写体度量把它的基线抬得忽高忽低，点亮后尤其明显）。
              // 颜色经 Tween 补间——墨→珊瑚的过渡本身就是「章落下来」
              // 的过程，跳变会把它拍成开关。
              ScaleTransition(
                scale: _stamp.isAnimating || _stamp.isCompleted
                    ? scale
                    : const AlwaysStoppedAnimation(1),
                child: RotationTransition(
                  turns: _stamp.isAnimating || _stamp.isCompleted
                      ? rotationTurns
                      : const AlwaysStoppedAnimation(0),
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: sparkleColor),
                    duration: NatsuMotion.medium,
                    curve: NatsuMotion.easing,
                    builder: (_, color, _) => CustomPaint(
                      size: const Size.square(18),
                      painter: _SparklePainter(color: color ?? sparkleColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: NatsuSpacing.sm),
              if (widget.resonated || !canInteract)
                // 计数被服务端校正时（乐观值 ≠ 真值）淡入换句而非硬切，
                // 用户看到的是「句子轻轻换了一下」不是数字跳变
                AnimatedSwitcher(
                  duration: NatsuMotion.short,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: NatsuMotion.easing,
                    ),
                    child: child,
                  ),
                  child: Text(
                    NatsuResonance.sentence(widget.count),
                    key: ValueKey(widget.count),
                    style: NatsuTypography.hwNote.copyWith(
                      color: canInteract
                          ? NatsuColors.inkSoft
                          : NatsuColors.disabledContent,
                    ),
                  ),
                )
              else
                // 两种字体（行动字 NotoSansSC / 句子 LXGW WenKai）必须活在
                // 同一个 TextSpan 段落里——段落内所有 span 共享同一条基线，
                // 字体度量差异由排版器消化；拆成两个 Row 子 Text 会各画各
                // 的基线（Row 的 center 对齐按包围盒不按基线），视觉高低错落
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '共鸣',
                        style: NatsuTypography.button.copyWith(
                          color: NatsuColors.inkBlue,
                        ),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: NatsuResonance.sentence(widget.count),
                        style: NatsuTypography.hwNote.copyWith(
                          color: NatsuColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ✦ 四角星描形——以中心为原点，四个尖角顶到盒缘，边用二次贝塞尔向内
/// 凹出 ✦ 的腰身。替代文本符号后不依赖字体度量，颜色随章任意着色。
class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    // 腰部收点离中心的比例（越小越瘦）
    const waist = 0.18;

    const up = Offset(0, -1), down = Offset(0, 1);
    const left = Offset(-1, 0), right = Offset(1, 0);

    Offset point(Offset dir, double k) => c + dir * (r * k);

    final path = Path()
      ..moveTo(point(up, 1).dx, point(up, 1).dy)
      // 顺时针：上尖 → 右尖 → 下尖 → 左尖，控制点压在腰部
      ..quadraticBezierTo(
        point(right, waist).dx,
        point(right, waist).dy,
        point(right, 1).dx,
        point(right, 1).dy,
      )
      ..quadraticBezierTo(
        point(down, waist).dx,
        point(down, waist).dy,
        point(down, 1).dx,
        point(down, 1).dy,
      )
      ..quadraticBezierTo(
        point(left, waist).dx,
        point(left, waist).dy,
        point(left, 1).dx,
        point(left, 1).dy,
      )
      ..quadraticBezierTo(
        point(up, waist).dx,
        point(up, waist).dy,
        point(up, 1).dx,
        point(up, 1).dy,
      )
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}
