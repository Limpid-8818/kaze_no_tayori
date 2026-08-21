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
  static String sentence(int count) => count <= 0
      ? '它还在等第一个同感的人'
      : '$count 个陌生人也曾有过这样的时刻';

  @override
  State<NatsuResonance> createState() => _NatsuResonanceState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('count', count));
    properties.add(FlagProperty('resonated',
        value: resonated, ifTrue: '已共鸣', ifFalse: '未共鸣'));
    properties.add(FlagProperty('hasOnResonate',
        value: onResonate != null, ifTrue: '可共鸣', ifFalse: '禁用'));
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
        tween: Tween(begin: 0.6, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(curved);
    // RotationTransition 收 turns（圈），-8° → 0° 换算成圈
    final rotationTurns =
        Tween(begin: -8.0 / 360, end: 0.0).animate(curved);

    return FocusableActionDetector(
      mouseCursor:
          _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowHoverHighlight:
          _enabled ? (h) => setState(() => _hovered = h) : null,
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
              // 未落章时 ✦ 静止在 scale 1 / 0°（controller 0）；落章动画驱动
              ScaleTransition(
                scale: _stamp.isAnimating || _stamp.isCompleted
                    ? scale
                    : const AlwaysStoppedAnimation(1),
                child: RotationTransition(
                  turns: _stamp.isAnimating || _stamp.isCompleted
                      ? rotationTurns
                      : const AlwaysStoppedAnimation(0),
                  child: Text(
                    '✦',
                    style: NatsuTypography.hwNote.copyWith(
                      color: sparkleColor,
                      fontSize: 18,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: NatsuSpacing.sm),
              if (widget.resonated || !canInteract)
                Text(
                  NatsuResonance.sentence(widget.count),
                  style: NatsuTypography.hwNote.copyWith(
                    color: canInteract
                        ? NatsuColors.inkSoft
                        : NatsuColors.disabledContent,
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
                        style: NatsuTypography.button
                            .copyWith(color: NatsuColors.inkBlue),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: NatsuResonance.sentence(widget.count),
                        style: NatsuTypography.hwNote
                            .copyWith(color: NatsuColors.inkFaint),
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
