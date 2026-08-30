/// 种子信 AI 辅助（采纳制）与 poem 落库测试。
///
/// 与 apps/app 写信页同款语义：AI 只产候选，采纳才进正文/短诗；
/// 服务端 poem 随创建 body 逐字提交（编辑态 poem=null 即清空）。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaze_admin/core/result.dart';
import 'package:kaze_admin/data/api/providers.dart';
import 'package:kaze_admin/features/seed/seed_screen.dart';

import '../helpers.dart';
import '../fakes/scripted_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('validatePoemCandidate', () {
    test('三行俳句 → 保留非空行', () {
      final lines = validatePoemCandidate('晚风翻过纸页\n\n蝉声停在句尾\n远山替我寄出\n');
      expect(lines, ['晚风翻过纸页', '蝉声停在句尾', '远山替我寄出']);
    });

    test('超过 4 行 → 废稿', () {
      expect(validatePoemCandidate('一\n二\n三\n四\n五'), isNull);
    });

    test('空/纯空白 → 废稿', () {
      expect(validatePoemCandidate(''), isNull);
      expect(validatePoemCandidate('  \n \n'), isNull);
    });
  });

  group('AI 候选解析', () {
    test('polish：正常返回候选取 polished 字段', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse.ok(200, {'polished': '海风替我问候你'}),
      ]);
      final container = makeContainer(adapter);
      addTearDown(container.dispose);

      expect(await container.read(adminApiProvider).polish('原文'), '海风替我问候你');
    });

    test('polish：响应形状不对 → invalidResponse', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse.ok(200, {'x': 1}),
      ]);
      final container = makeContainer(adapter);
      addTearDown(container.dispose);

      await expectLater(
        container.read(adminApiProvider).polish('原文'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.invalidResponse,
          ),
        ),
      );
    });

    test('poem：503 feature_disabled → 可降级失败', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse.ok(503, {
          'error': {'code': 'feature_disabled', 'message': 'AI 关闭'},
        }),
      ]);
      final container = makeContainer(adapter);
      addTearDown(container.dispose);

      await expectLater(
        container.read(adminApiProvider).poem('正文'),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.kind, 'kind', ApiErrorKind.featureDisabled)
              .having((e) => e.isDegradable, 'isDegradable', isTrue),
        ),
      );
    });
  });

  group('save 携带 poem', () {
    test('新建：已采纳短诗随 body 逐字提交（trim）', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse.ok(200, {'items': <Object>[], 'next_cursor': null}),
        ScriptedResponse.ok(200, detailJson(status: 'public')),
        ScriptedResponse.ok(200, {'items': <Object>[], 'next_cursor': null}),
      ]);
      final container = makeContainer(adapter);
      addTearDown(container.dispose);

      final controller = container.read(seedControllerProvider.notifier);
      await controller.start();
      await controller.save(
        SeedDraft.empty(),
        lat: '',
        lon: '',
        textBlocks: ['你好'],
        placeLabel: '',
        weatherText: '',
        poem: ' 晚风掠过海面\n灯塔独自亮着 ',
      );

      final data = adapter.requests[1].data;
      final body = data is String
          ? jsonDecode(data) as Map<String, dynamic>
          : data! as Map<String, dynamic>;
      expect(body['poem'], '晚风掠过海面\n灯塔独自亮着');
    });

    test('新建：无诗 → poem 显式 null（编辑态保存即清空，口径一致）', () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse.ok(200, {'items': <Object>[], 'next_cursor': null}),
        ScriptedResponse.ok(200, detailJson(status: 'public')),
        ScriptedResponse.ok(200, {'items': <Object>[], 'next_cursor': null}),
      ]);
      final container = makeContainer(adapter);
      addTearDown(container.dispose);

      final controller = container.read(seedControllerProvider.notifier);
      await controller.start();
      await controller.save(
        SeedDraft.empty(),
        lat: '',
        lon: '',
        textBlocks: ['你好'],
        placeLabel: '',
        weatherText: '',
      );

      final data = adapter.requests[1].data;
      final body = data is String
          ? jsonDecode(data) as Map<String, dynamic>
          : data! as Map<String, dynamic>;
      expect(body['poem'], isNull);
    });
  });
}
