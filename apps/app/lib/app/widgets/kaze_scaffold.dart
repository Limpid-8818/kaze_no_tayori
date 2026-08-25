/// 普通页面的统一视觉与布局骨架。
library;

import 'package:flutter/material.dart';

import '../theme.dart';

class KazeScaffold extends StatelessWidget {
  const KazeScaffold({
    required this.body,
    this.title,
    this.actions,
    this.centerTitle = true,
    this.scrollable = true,
    this.padding = const EdgeInsets.all(KazeSpacing.lg),
    this.maxContentWidth = 480,
    super.key,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool scrollable;
  final EdgeInsetsGeometry padding;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(padding: padding, child: body),
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: KazeTheme.skyGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: title == null
            ? null
            : AppBar(
                centerTitle: centerTitle,
                title: Text(title!),
                actions: actions,
              ),
        body: SafeArea(
          child: scrollable
              ? SingleChildScrollView(child: content)
              : SizedBox.expand(child: content),
        ),
      ),
    );
  }
}
