/// 设置页。
///
/// 只展示已经有真实消费者的设置。不能先做一个“能保存”但对 App 无影响的开关。
library;

import 'package:flutter/material.dart';

import '../../app/widgets/kaze_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KazeScaffold(
      title: '设置',
      body: Text(
        '设置项会在对应能力真正接入后出现。\n'
        '定位权限仍由需要位置的场景按需申请，可随时在系统设置中调整。',
      ),
    );
  }
}
