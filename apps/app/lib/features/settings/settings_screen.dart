/// 设置页 —— 只展示已经有真实消费者的设置。
///
/// 「背景自动跟随天色」的消费方是全局天色控制器（app/controllers/
/// sky_controller.dart，F8）：关闭后全 App 回退默认昼·晴。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../app/theme.dart';
import '../../app/widgets/kaze_scaffold.dart';
import 'settings_store.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final skyAuto = ref.watch(settingsProvider.select((s) => s.skyAutoEnabled));
    final controller = ref.read(settingsProvider.notifier);

    return KazeScaffold(
      title: '设置',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('外观', style: theme.textTheme.labelMedium),
          const SizedBox(height: KazeSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(KazeSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('背景自动跟随天色', style: theme.textTheme.titleMedium),
                        const SizedBox(height: KazeSpacing.xs),
                        Text(
                          '天空随当地的时间与天气变换氛围；'
                          '关闭后固定为昼·晴。',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: KazeSpacing.md),
                  NatsuSwitch(
                    value: skyAuto,
                    onChanged: (v) => controller.setSkyAutoEnabled(v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
