/// 纸叠切换台测试 —— 换纸的叠放过渡：新旧共存、方向落定、同 Key 不换、
/// 高度差平滑收放不跳位。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kazenotayori/app/widgets/kaze_paper_stack.dart';

void main() {
  testWidgets('换 Key：过渡期新旧两张纸共存，落定后只剩新纸', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KazePaperStack(child: Text('纸一', key: ValueKey('paper'))),
        ),
      ),
    );
    expect(find.text('纸一'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KazePaperStack(child: Text('纸二', key: ValueKey('envelope'))),
        ),
      ),
    );
    // 过渡中途：Stack 里两张纸同时在（新纸压着旧纸落下）
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('纸一'), findsOneWidget);
    expect(find.text('纸二'), findsOneWidget);

    // 新纸正在落下：透明度在途中（>0 且 <1，driftEasing 中段约 0.2）。
    // MaterialApp 的路由转场自带 FadeTransition 祖先，只在切换台内部找：
    // layoutBuilder 里 previousChildren 在前、currentChild 殿后。
    final incoming = find
        .descendant(
          of: find.byType(KazePaperStack),
          matching: find.byType(FadeTransition),
        )
        .last;
    final incomingOpacity = tester.widget<FadeTransition>(incoming).opacity;
    expect(incomingOpacity.value, allOf(greaterThan(0), lessThan(1)));

    await tester.pumpAndSettle();
    expect(find.text('纸一'), findsNothing);
    expect(find.text('纸二'), findsOneWidget);
  });

  testWidgets('同 Key 重建不触发换纸：旧内容即刻让位，无过渡期', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KazePaperStack(child: Text('纸一', key: ValueKey('paper'))),
        ),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KazePaperStack(child: Text('改写', key: ValueKey('paper'))),
        ),
      ),
    );
    // Key 未变 → AnimatedSwitcher 视为同一张纸，原地更新，旧文本即刻消失
    expect(find.text('纸一'), findsNothing);
    expect(find.text('改写'), findsOneWidget);
  });

  testWidgets('高矮不同的纸：换纸尺寸平滑收放，起始帧不瞬跳、落定精确', (tester) async {
    // 回归：AnimatedSwitcher 的叠在换纸起止两帧曾瞬变到最大者、再瞬塌
    // 回独苗，落定帧因此跳位——AnimatedSize 负责把这两次突变插值掉。
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KazePaperStack(
            child: SizedBox(width: 200, height: 100, key: ValueKey('paper')),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(KazePaperStack)).height, 100);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KazePaperStack(
            child: SizedBox(width: 200, height: 300, key: ValueKey('envelope')),
          ),
        ),
      ),
    );
    // 起始帧从旧尺寸起步，不瞬跳到新纸高度
    expect(tester.getSize(find.byType(KazePaperStack)).height, 100);

    await tester.pump(const Duration(milliseconds: 160));
    final mid = tester.getSize(find.byType(KazePaperStack)).height;
    expect(mid, allOf(greaterThan(100), lessThan(300)));

    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(KazePaperStack)).height, 300);
  });
}
