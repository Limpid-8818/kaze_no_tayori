/// 柔和化下拉刷新指示器 —— 列表页（发掘/我的信/抄本）统一出口。
///
/// 默认 Material 指示器是纯白圆角方块 + 主题深墨蓝转圈，浮在暖纸色
/// 页面上很跳；这里改暖纸底、淡墨细线圈、去投影，融进纸面。
library;

import 'package:flutter/material.dart';

import '../theme.dart';

class KazeRefreshIndicator extends StatelessWidget {
  const KazeRefreshIndicator({
    required this.onRefresh,
    required this.child,
    super.key,
  });

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: KazeColors.inkSoft,
      backgroundColor: KazeColors.envelope,
      elevation: 0,
      strokeWidth: 2,
      onRefresh: onRefresh,
      child: child,
    );
  }
}
