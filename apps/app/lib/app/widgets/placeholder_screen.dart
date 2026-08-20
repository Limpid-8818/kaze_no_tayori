/// 脚手架期的占位页。
///
/// 每个 feature 先挂一个它，保证路由可通、能点进去；实现某个 feature 时
/// 把对应的 `*_screen.dart` 换成真实 UI（并加上 `*_controller.dart`）。
///
/// 放在 lib/app/widgets/ 而非某个 feature 里：跨 feature 复用的东西不许塞进 feature。
library;

import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    required this.intent,
    this.prdRef,
    super.key,
  });

  /// 页面标题，用产品语言。
  final String title;

  /// 这一页要承担什么。写清楚，实现时不用回头翻 PRD。
  final String intent;

  /// 对应的 PRD 小节，如 '6.3'。
  final String? prdRef;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  intent,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  prdRef == null ? '尚未实现' : '尚未实现 · PRD $prdRef',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
