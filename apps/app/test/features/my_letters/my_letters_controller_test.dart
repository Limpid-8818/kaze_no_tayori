/// 我的信控制器测试（F6）：列表加载与徽标映射、空/错误态、
/// 下架成功翻状态 + 提示、下架失败仅提示不动列表。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/data/api/api_client.dart';
import 'package:kazenotayori/data/api/providers.dart';
import 'package:kazenotayori/data/models/letter.dart';
import 'package:kazenotayori/features/my_letters/my_letters_controller.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/scripted_adapter.dart';

Map<String, dynamic> _ownedJson(
  String id, {
  required String status,
  String? poem,
  Duration ago = const Duration(hours: 4),
}) => {
  'id': id,
  'blocks': const [
    {'type': 'text', 'text': '在海堤上写完这封，浪来过两次，纸角湿了一点。'},
  ],
  'poem': poem,
  'theme_id': 'natsu',
  'delivery_mode': 'drift',
  'place_label': '浙江 · 舟山',
  'weather': const {'text': '晴', 'temp_c': 29.0},
  'parent_letter_id': null,
  'counts': const {
    'read': 0,
    'resonance': 0,
    'voice': 0,
    'reply': 0,
    'saved': 0,
  },
  'created_at': DateTime.now().subtract(ago).toIso8601String(),
  'status': status,
};

ScriptedResponse _page(List<Map<String, dynamic>> items) =>
    ScriptedResponse.ok(200, {'items': items, 'next_cursor': null});

DioException _server(String path) => DioException(
  requestOptions: RequestOptions(path: path, baseUrl: 'http://test'),
  response: Response(
    requestOptions: RequestOptions(path: path, baseUrl: 'http://test'),
    statusCode: 503,
    data: {
      'error': {'code': 'service_unavailable', 'message': 'x'},
    },
  ),
);

void main() {
  late ScriptedAdapter adapter;

  ProviderContainer container(List<ScriptedResponse> script) {
    adapter = ScriptedAdapter(script);
    final c = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          ApiClient(
            dio: Dio(
              BaseOptions(
                baseUrl: 'http://test',
                contentType: Headers.jsonContentType,
              ),
            )..httpClientAdapter = adapter,
            store: fakeSecureStore(),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('就绪：四态徽标映射与摘要字段在位（含无诗回退预览）', () async {
    final c = container([
      _page([
        _ownedJson('mine_a', status: 'public', poem: '候鸟排成人字\n把我的问候带走\n往更南的南方'),
        _ownedJson('mine_b', status: 'pending'),
        _ownedJson('mine_c', status: 'rejected'),
        _ownedJson('mine_d', status: 'taken_down'),
      ]),
    ]);

    await c.read(myLettersControllerProvider.notifier).start();

    final state = c.read(myLettersControllerProvider);
    expect(state.phase, MyLettersPhase.ready);
    expect(state.items, hasLength(4));
    expect(
      [for (final item in state.items) item.statusLabel],
      ['公开中', '审核中', '未通过', '已下架'],
    );
    // 有诗 → 逐行；无诗 → 首个文字块预览（共享 letter_preview 口径）
    expect(state.items[0].poemLines, hasLength(3));
    expect(state.items[1].previewText, contains('浪来过两次'));
    expect(state.items[0].timeLabel, contains('小时前'));
  });

  test('一封都没有：empty 态，页面给「去写第一封信」的余地', () async {
    final c = container([_page(const [])]);

    await c.read(myLettersControllerProvider.notifier).start();

    expect(c.read(myLettersControllerProvider).phase, MyLettersPhase.empty);
  });

  test('拉取失败：error 态，不发任何写请求', () async {
    final c = container([ScriptedResponse.fail(_server('/v1/me/letters'))]);

    await c.read(myLettersControllerProvider.notifier).start();

    expect(c.read(myLettersControllerProvider).phase, MyLettersPhase.error);
    expect(adapter.requests.single.uri.path, '/v1/me/letters');
  });

  test('下架成功：DELETE 命中，本地翻 taken_down 并发一次性提示', () async {
    final c = container([
      _page([_ownedJson('mine_a', status: 'public')]),
      const ScriptedResponse.ok(204),
    ]);
    final controller = c.read(myLettersControllerProvider.notifier);
    await controller.start();

    await controller.takeDown('mine_a');

    final state = c.read(myLettersControllerProvider);
    expect(state.items.single.status, LetterStatus.takenDown);
    expect(state.items.single.statusLabel, '已下架');
    expect(state.notice?.message, '已经下架了');

    final request = adapter.requests.last;
    expect(request.method, 'DELETE');
    expect(request.uri.path, '/v1/me/letters/mine_a');
  });

  test('下架失败：状态原样保留，只发失败提示，不抛错', () async {
    final c = container([
      _page([_ownedJson('mine_a', status: 'pending')]),
      ScriptedResponse.fail(_server('/v1/me/letters/mine_a')),
    ]);
    final controller = c.read(myLettersControllerProvider.notifier);
    await controller.start();

    await controller.takeDown('mine_a');

    final state = c.read(myLettersControllerProvider);
    expect(state.items.single.status, LetterStatus.pending);
    expect(state.notice?.message, '没能下架，稍后再试');
  });

  test('静默刷新成功：列表原位替换，不清相位不闪加载态', () async {
    final c = container([
      _page([_ownedJson('mine_a', status: 'pending')]),
      _page([
        _ownedJson('mine_b', status: 'public', poem: '候鸟排成人字\n把我的问候带走\n往更南的南方'),
      ]),
    ]);
    final controller = c.read(myLettersControllerProvider.notifier);
    await controller.start();

    await controller.refresh();

    final state = c.read(myLettersControllerProvider);
    expect(state.phase, MyLettersPhase.ready);
    expect(state.items.single.id, 'mine_b');
    expect(state.items.single.statusLabel, '公开中');
  });

  test('静默刷新失败：手里有列表就当没发生（保持原状，不出错误态）', () async {
    final c = container([
      _page([_ownedJson('mine_a', status: 'pending')]),
      ScriptedResponse.fail(_server('/v1/me/letters')),
    ]);
    final controller = c.read(myLettersControllerProvider.notifier);
    await controller.start();

    await controller.refresh();

    final state = c.read(myLettersControllerProvider);
    expect(state.phase, MyLettersPhase.ready);
    expect(state.items.single.id, 'mine_a');
  });

  test('静默刷新失败且无可展示内容：落 error 态', () async {
    final c = container([ScriptedResponse.fail(_server('/v1/me/letters'))]);

    await c.read(myLettersControllerProvider.notifier).refresh();

    expect(c.read(myLettersControllerProvider).phase, MyLettersPhase.error);
  });

  test('提示流水号跨状态重建仍单调（refresh/start 不重置序号）', () async {
    final c = container([
      _page([_ownedJson('mine_a', status: 'pending')]),
      ScriptedResponse.fail(_server('/v1/me/letters/mine_a')),
      _page([_ownedJson('mine_a', status: 'pending')]),
      ScriptedResponse.fail(_server('/v1/me/letters/mine_a')),
    ]);
    final controller = c.read(myLettersControllerProvider.notifier);
    await controller.start();

    await controller.takeDown('mine_a');
    final firstSeq = c.read(myLettersControllerProvider).notice!.seq;
    await controller.start(); // 整颗重建 state，旧 notice 被丢弃
    expect(c.read(myLettersControllerProvider).notice, isNull);

    await controller.takeDown('mine_a');
    final secondSeq = c.read(myLettersControllerProvider).notice!.seq;

    expect(secondSeq, greaterThan(firstSeq));
  });
}
