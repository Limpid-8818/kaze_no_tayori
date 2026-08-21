import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natsu_no_tegami/src/components/components.dart';
import 'package:natsu_no_tegami/src/tokens/natsu_tokens.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData(fontFamily: 'NotoSansSC'),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('注册表完整性', () {
    test('每槽数量符合「代表资产」定位（防缩水防膨胀）', () {
      expect(NatsuSkins.bySlot(SkinSlot.stamp).length, 4);
      expect(NatsuSkins.bySlot(SkinSlot.postmark).length, 4);
      expect(NatsuSkins.bySlot(SkinSlot.decor).length, greaterThanOrEqualTo(3));
      expect(
        NatsuSkins.bySlot(SkinSlot.postcard),
        isEmpty,
        reason: '明信片槽位保留，待「信」的形态确定',
      );
      expect(NatsuSkins.all.length, lessThanOrEqualTo(18));
    });

    test('ID 全局唯一且匹配 <slot>.<motive>-<数字> 规范', () {
      final ids = NatsuSkins.all.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'ID 不得重复');
      final pattern = RegExp(
        r'^(postmark|stamp|decor|postcard)\.[a-z]+-\d{2}$',
      );
      for (final id in ids) {
        expect(id, matches(pattern), reason: '$id 不符合序列化 ID 规范');
        expect(
          NatsuSkins.byId(id)!.slot.name,
          id.split('.').first,
          reason: '$id 的 slot 前缀与实际槽位不符',
        );
      }
    });

    test('byId 全量可查，未注册 id 返回 null', () {
      for (final a in NatsuSkins.all) {
        expect(NatsuSkins.byId(a.id), same(a));
      }
      expect(NatsuSkins.byId('stamp.nowhere-99'), isNull);
    });

    test('painter 全部无状态（shouldRepaint 恒 false）', () {
      for (final a in NatsuSkins.all) {
        expect(
          a.painter.shouldRepaint(a.painter),
          isFalse,
          reason: '${a.id} 的 painter 必须无状态（const 资产契约）',
        );
      }
    });
  });

  group('coral 配给纪律', () {
    test('邮戳槽全珊瑚（盖章油墨统一）', () {
      for (final a in NatsuSkins.bySlot(SkinSlot.postmark)) {
        expect(a.ink, NatsuColors.coralStamp, reason: '${a.id} 邮戳油墨必须统一珊瑚');
      }
    });

    test('装饰槽禁珊瑚/错误/顶光浅色（配给 + 可见性）', () {
      const forbidden = [
        NatsuColors.coralStamp, // 配给：装饰不承载旅行语义
        NatsuColors.error, // 语义保留
        NatsuColors.sunlight, // 顶光浅色作线不可见
      ];
      for (final a in NatsuSkins.bySlot(SkinSlot.decor)) {
        expect(a.ink, isNot(anyOf(forbidden)), reason: '${a.id} 装饰用色越界');
      }
    });
  });

  group('消费端视觉契约', () {
    testWidgets('Postmark 无 emblem = 纯文字（零回归；地名弧排逐字）', (tester) async {
      await tester.pumpWidget(
        _wrap(const Postmark(place: '鎌倉', date: '2026.08.20')),
      );
      expect(find.text('鎌'), findsOneWidget);
      expect(find.text('倉'), findsOneWidget);
      expect(find.text('2026.08.20'), findsOneWidget);
    });

    testWidgets('Postmark 有 emblem：接口保留（暂不参与构图），文字仍在', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Postmark(
            place: '鎌倉',
            date: '2026.08.20',
            emblem: SkinMotive('postmark.wave-04'),
          ),
        ),
      );
      // 定版构图 = 纯文本三段式：emblem 暂不渲染（接口保留，图样版
      // 后续再定）——传了也不破坏文字
      expect(find.text('鎌'), findsOneWidget);
      expect(find.text('倉'), findsOneWidget);
      expect(find.text('2026.08.20'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Postmark),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('StampPiece + SkinMotive：锯齿边与面值不破坏', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StampPiece(
            seedId: 'skin-stamp-1',
            motive: SkinMotive('stamp.sea-01'),
          ),
        ),
      );
      expect(find.byType(ClipPath), findsOneWidget);
      expect(find.text('夏'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StampPiece),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('SkinMotive 未注册 id 渲染为空不抛', (tester) async {
      await tester.pumpWidget(_wrap(const SkinMotive('decor.nowhere-99')));
      // 断言限定在 SkinMotive 子树内——MaterialApp 自身含框架级 CustomPaint
      expect(
        find.descendant(
          of: find.byType(SkinMotive),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('SkinDecor 倾斜 == 种子派生值（确定性）', (tester) async {
      const seed = 'decor-test-1';
      await tester.pumpWidget(
        _wrap(const SkinDecor(assetId: 'decor.leaf-03', seedId: seed)),
      );

      // rotate 在 translate 外层 → DFS 首个 Transform；其 storage[1] = sin(angle)
      final t = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(SkinDecor),
              matching: find.byType(Transform),
            )
            .first,
      );
      final actual = math.asin(t.transform.storage[1].clamp(-1.0, 1.0));
      final expected = NatsuImperfection.tiltOf(seed) * math.pi / 180;
      expect(actual, closeTo(expected, 1e-6), reason: 'SkinDecor 倾斜应由种子确定性派生');
    });

    testWidgets('SkinDecor 未注册 id → 渲染为空不抛', (tester) async {
      await tester.pumpWidget(
        _wrap(const SkinDecor(assetId: 'decor.nowhere-99', seedId: 'x')),
      );
      expect(
        find.descendant(
          of: find.byType(SkinDecor),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });
  });

  group('LetterSkin 序列化（D20 永久绑定）', () {
    test('toJson/fromJson round-trip 相等', () {
      const skin = LetterSkin(
        stampId: 'stamp.dusk-03',
        postmarkEmblemId: 'postmark.tram-02',
        decorIds: ['decor.shell-01', 'decor.hanabi-02'],
      );
      final restored = LetterSkin.fromJson(skin.toJson());
      expect(restored.stampId, 'stamp.dusk-03');
      expect(restored.postmarkEmblemId, 'postmark.tram-02');
      expect(restored.decorIds, ['decor.shell-01', 'decor.hanabi-02']);
      expect(restored.postcardId, isNull);
    });

    test('空实例序列化为 {}（省字段设计）', () {
      expect(const LetterSkin().toJson(), isEmpty);
    });

    test('fromJson 容忍缺失字段（旧信向前兼容）', () {
      final skin = LetterSkin.fromJson({});
      expect(skin.stampId, isNull);
      expect(skin.decorIds, isEmpty);
    });
  });
}
