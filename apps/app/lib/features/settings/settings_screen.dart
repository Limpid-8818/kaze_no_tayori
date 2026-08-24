/// 设置页 — 按画布「夏の手紙 v2 · Screen/Settings」实现。
///
/// 本期落一个真实偏好项「主题随环境变化」（页面天空背景是否随场景天气×
/// 时段变化，接 themeSyncProvider → SharedPreferences）。行组件体系在
/// lib/app/widgets/settings_tiles.dart：未来新增设置项 = 往 Section 里
/// 加一行 tile，不动页面布局。
///
/// 画布其余行（回信通知/定位服务/位置模糊/主题皮肤/账号与绑定/意见反馈/
/// 清除缓存/关于风信/退出登录）按需求裁剪暂不渲染——SettingsNavTile
/// 骨架已备好；画布底注的版本信息归未来的「关于」页。返回箭头由 AppBar
/// 在路由可返回时自动提供（push 进入）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/widgets/settings_tiles.dart';
import 'providers/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Notifier build 同步返回默认 false；持久化值在此异步覆写
    // （providers 文件头声明的分工）。
    ref.read(themeSyncProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeSync = ref.watch(themeSyncProvider);

    return DecoratedBox(
      // 环境是天空（与 Home 同一渐变），纸卡浮于其上
      decoration: const BoxDecoration(gradient: KazeTheme.skyGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: true,
          // 画布标题 17 SemiBold → titleMedium（bodyStrong 16 w500，最近档）
          title: Text('设置', style: theme.textTheme.titleMedium),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KazeSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SettingsSection(
                  label: '偏好',
                  tiles: [
                    SettingsSwitchTile(
                      icon: Icons.cloud_outlined,
                      title: '主题随环境变化',
                      value: themeSync,
                      onChanged: ref
                          .read(themeSyncProvider.notifier)
                          .setEnabled,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
