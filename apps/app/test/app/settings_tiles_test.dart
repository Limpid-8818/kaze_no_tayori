/// 设置行组件体系测试：Section 结构 / SwitchTile 行为 / NavTile 行为。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/app/widgets/settings_tiles.dart';

Widget wrap(Widget child) => MaterialApp(
  theme: KazeTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('SettingsSection：组标签 + 卡片 + 行间恰一条分隔线', (tester) async {
    await tester.pumpWidget(
      wrap(
        SettingsSection(
          label: '偏好',
          tiles: const [
            SettingsSwitchTile(
              icon: Icons.cloud_outlined,
              title: '主题随环境变化',
              value: false,
              onChanged: null,
            ),
            SettingsNavTile(
              icon: Icons.palette_outlined,
              title: '主题皮肤',
              value: '夏',
            ),
          ],
        ),
      ),
    );

    expect(find.text('偏好'), findsOneWidget);
    expect(find.text('主题随环境变化'), findsOneWidget);
    expect(find.text('主题皮肤'), findsOneWidget);
    expect(find.text('夏'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
    // 两行之间恰一条纸缘分隔线
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('SettingsSwitchTile：点行与点开关本体都触发 onChanged 翻转', (tester) async {
    var current = false;
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) => SettingsSection(
            label: '偏好',
            tiles: [
              SettingsSwitchTile(
                icon: Icons.cloud_outlined,
                title: '主题随环境变化',
                value: current,
                onChanged: (v) => setState(() => current = v),
              ),
            ],
          ),
        ),
      ),
    );

    // 点行内标题区域 → 整行命中
    await tester.tap(find.text('主题随环境变化'));
    await tester.pumpAndSettle();
    expect(current, isTrue);

    // 点开关本体 → 开关自身命中，等效翻转
    await tester.tap(find.byType(NatsuSwitch));
    await tester.pumpAndSettle();
    expect(current, isFalse);
  });

  testWidgets('SettingsNavTile：onTap 可点，值与 chevron 齐备', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      wrap(
        SettingsNavTile(
          icon: Icons.palette_outlined,
          title: '主题皮肤',
          value: '夏',
          onTap: () => tapped++,
        ),
      ),
    );

    await tester.tap(find.text('主题皮肤'));
    await tester.pumpAndSettle();
    expect(tapped, 1);
    expect(find.text('夏'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('SettingsNavTile：值可空，只出 chevron', (tester) async {
    await tester.pumpWidget(
      wrap(const SettingsNavTile(icon: Icons.info_outline, title: '关于风信')),
    );

    expect(find.text('关于风信'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });
}
