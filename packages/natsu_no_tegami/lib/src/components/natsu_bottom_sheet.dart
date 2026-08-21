import 'package:flutter/material.dart';

import '../tokens/natsu_tokens.dart';

/// 夏の手紙 · 底部弹层 — 从桌沿推上来的纸
///
/// 私有 PopupRoute（纯 widgets，不依赖 Material showModalBottomSheet）：
/// scrim 遮罩 + long 上滑入场。面 = 纸白、仅顶部圆角、paperResting 阴影
/// （纸被推上桌沿），顶部 36×4 纸缘拖拽把手，底部让出安全区。
Future<T?> showNatsuSheet<T>({
  required BuildContext context,
  required Widget child,
  Widget? title,
  bool barrierDismissible = true,
}) {
  return Navigator.of(context).push<T>(
    _SheetRoute<T>(child: child, title: title, dismissible: barrierDismissible),
  );
}

class _SheetRoute<T> extends PopupRoute<T> {
  _SheetRoute({required this.child, this.title, this.dismissible = true});

  final Widget child;
  final Widget? title;
  final bool dismissible;

  @override
  Color? get barrierColor => NatsuColors.scrim;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => '关闭';

  @override
  Duration get transitionDuration => NatsuMotion.long;

  @override
  Duration get reverseTransitionDuration => NatsuMotion.medium;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return NatsuBottomSheet(title: title, child: child);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: NatsuMotion.easing,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  }
}

/// 弹层面 — 通常经 [showNatsuSheet] 弹出，不直接使用
class NatsuBottomSheet extends StatelessWidget {
  const NatsuBottomSheet({super.key, required this.child, this.title});

  final Widget? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: NatsuSpacing.sheetMaxW),
        child: DefaultTextStyle(
          // 纯 widgets 路由无 Material 祖先：切断 debug 回退样式（红字黄
          // 双下划线）经 merge 泄漏进 Text 的 decoration 字段。
          style: NatsuTypography.body,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: NatsuColors.paperWhite,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(NatsuRadius.card),
              ),
              border: Border.all(color: NatsuColors.paperEdge, width: 1),
              boxShadow: NatsuShadows.paperResting,
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: NatsuSpacing.sm),
                  // 拖拽把手 — 36×4 纸缘药丸
                  Center(
                    child: Container(
                      width: NatsuSpacing.handleW,
                      height: NatsuSpacing.handleH,
                      decoration: BoxDecoration(
                        color: NatsuColors.paperEdge,
                        borderRadius: BorderRadius.circular(
                          NatsuSpacing.handleH / 2,
                        ),
                      ),
                    ),
                  ),
                  if (title != null) ...[
                    const SizedBox(height: NatsuSpacing.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: NatsuSpacing.lg,
                      ),
                      child: DefaultTextStyle(
                        style: NatsuTypography.heading.copyWith(
                          color: NatsuColors.inkBlue,
                          fontSize: 22,
                          height: 1.3,
                        ),
                        child: title!,
                      ),
                    ),
                  ],
                  const SizedBox(height: NatsuSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NatsuSpacing.lg,
                    ),
                    child: child,
                  ),
                  const SizedBox(height: NatsuSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
