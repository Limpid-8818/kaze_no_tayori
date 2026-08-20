import 'package:flutter/material.dart';

import '../../app/widgets/placeholder_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '设置',
      intent: 'AI 辅助开关、位置精度、删除我的数据。',
      prdRef: '8.1',
    );
  }
}
