/// 设置页测试 —— 「背景自动跟随天色」是有真实消费链路的开关（F8）。
///
/// 旧守卫「主题同步未接入不得渲染开关」的使命随 F8 接线完成；
/// 现在反过来锁死：开关必须存在、且操作它必须改写全局天色。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import 'package:kazenotayori/app/controllers/sky_controller.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/features/settings/settings_screen.dart';
import 'package:kazenotayori/features/settings/settings_store.dart';

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: const SettingsScreen(),
        theme: KazeTheme.light(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 卸载树并泵一帧：让 Riverpod 完成 provider dispose（天色 ticker 取消），
/// 否则测试收尾的 pending-timer 不变量会失败。
Future<void> _unload(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('分组卡片渲染真实开关与说明', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _pump(tester, container);

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('背景自动跟随天色'), findsOneWidget);
    expect(find.textContaining('昼·晴'), findsOneWidget);
    expect(find.byType(NatsuSwitch), findsOneWidget);
    // 底部提示小字已按用户要求移除，页面只保留开关卡片
    expect(find.textContaining('定位权限'), findsNothing);
    expect(container.read(settingsProvider).skyAutoEnabled, isTrue);
    await _unload(tester);
    container.dispose(); // 同步销毁 → 天色 ticker 立即取消（避免 pending timer）
  });

  testWidgets('关闭开关立即把全局天色拉回默认昼·晴', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(skyControllerProvider.notifier);
    notifier.clock = () => DateTime(2026, 8, 27, 23); // 深夜，自动档≠昼晴
    notifier.refresh();
    expect(
      container.read(skyControllerProvider).daypart,
      isNot(KazeDaypart.noon),
    );

    await _pump(tester, container);

    await tester.tap(find.byType(NatsuSwitch));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).skyAutoEnabled, isFalse);
    expect(
      container.read(skyControllerProvider),
      const SkyState(weather: KazeWeather.sunny, daypart: KazeDaypart.noon),
    );
    // 开关视觉同步为关
    final sw = tester.widget<NatsuSwitch>(find.byType(NatsuSwitch));
    expect(sw.value, isFalse);
    await _unload(tester);
    container.dispose(); // 同步销毁 → 天色 ticker 立即取消（避免 pending timer）
  });
}
