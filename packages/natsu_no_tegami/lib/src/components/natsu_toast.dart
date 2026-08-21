import 'dart:async';

import 'package:flutter/material.dart';

import '../tokens/natsu_tokens.dart';

/// 夏の手紙 · 轻提示 — 墨蓝纸条
///
/// inkBlue 深底 + 暖白字（对比度已锁定），无阴影（转瞬即逝的 chrome，
/// 深底自带层次）。底部居中、让出安全区。入场 = 上滑 8px + fade（medium），
/// 停留 2.4s 后反向消失。
///
/// Overlay 必须在调用时**同步**捕获（rootOverlay 抗路由切换），
/// 之后只操作 OverlayEntry——不持有 context。
void showNatsuToast(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) =>
        _ToastHost(message: message, onDismissed: () => entry.remove()),
  );
  overlay.insert(entry);
}

/// Toast 宿主 — 入场/停留/退场状态机
class _ToastHost extends StatefulWidget {
  const _ToastHost({required this.message, required this.onDismissed});

  final String message;
  final VoidCallback onDismissed;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NatsuMotion.medium,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(NatsuMotion.toastDuration, () async {
      await _controller.reverse();
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset + NatsuSpacing.lg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: NatsuSpacing.toastMaxW),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final curved = CurvedAnimation(
                parent: _controller,
                curve: NatsuMotion.easing,
              );
              return Transform.translate(
                offset: Offset(0, 8 * (1 - curved.value)),
                child: Opacity(opacity: curved.value, child: child),
              );
            },
            child: NatsuToast(message: widget.message),
          ),
        ),
      ),
    );
  }
}

/// Toast 面 — 通常经 [showNatsuToast] 弹出；导出以便测试复用
class NatsuToast extends StatelessWidget {
  const NatsuToast({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      // Overlay 无 Material 祖先：切断 debug 回退样式（红字黄双下划线）
      // 经 merge 泄漏进 Text 的 decoration 字段。
      style: NatsuTypography.button.copyWith(color: NatsuColors.onInk),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: NatsuSpacing.sm + 2,
          horizontal: NatsuSpacing.md,
        ),
        decoration: BoxDecoration(
          color: NatsuColors.inkBlue,
          borderRadius: BorderRadius.circular(NatsuRadius.card),
        ),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
