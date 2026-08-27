/// 普通页面的统一视觉与布局骨架。
library;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'kaze_sky_box.dart';

class KazeScaffold extends StatelessWidget {
  const KazeScaffold({
    required this.body,
    this.title,
    this.actions,
    this.bottom,
    this.centerTitle = true,
    this.scrollable = true,
    this.padding = const EdgeInsets.all(KazeSpacing.lg),
    this.maxContentWidth = 480,
    this.backgroundGradient,
    super.key,
  });

  final Widget body;
  final String? title;

  /// Scaffold.bottomNavigationBar —— 阅读页这类「内容滚动 + 底部常驻动作」的
  /// 布局用；普通页面不传。
  final Widget? bottom;

  final List<Widget>? actions;
  final bool centerTitle;
  final bool scrollable;
  final EdgeInsetsGeometry padding;
  final double maxContentWidth;

  /// 页面自带的天空 —— 读信页锁定信件天色专用；null 时跟随全局天色联动。
  final Gradient? backgroundGradient;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(padding: padding, child: body),
      ),
    );

    return KazeSkyBox(
      gradient: backgroundGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: title == null
            ? null
            : AppBar(
                centerTitle: centerTitle,
                title: Text(title!),
                actions: actions,
              ),
        bottomNavigationBar: bottom,
        body: SafeArea(
          child: scrollable
              ? SingleChildScrollView(child: content)
              : SizedBox.expand(child: content),
        ),
      ),
    );
  }
}
