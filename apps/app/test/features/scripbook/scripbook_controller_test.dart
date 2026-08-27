/// 抄本控制器测试（F7）：列表加载与摘要字段映射、空/错误态、
/// 移出成功本地移除 + 提示（最后一封清空转 empty）、
/// 移出失败仅提示不动列表、静默刷新双态。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/data/api/api_client.dart';
import 'package:kazenotayori/data/api/providers.dart';
import 'package:kazenotayori/features/scripbook/scripbook_controller.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/scripted_adapter.dart';

Map<String, dynamic> _letterJson(
  String id, {
  String? poem,
  Duration ago = const Duration(hours: 4),
  String? signature,
}) => {
  'id': id,
  'blocks': const [
    {'type': 'text', 'text': '在海堤上写完这封，浪来过两次，纸角湿了一点。'},
  ],
  'poem': poem,
  'signature': signature,
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

  test('就绪：俳句逐行 / 无诗回退预览 / 地点时间在位', () async {
    final c = container([
      _page([
        _letterJson('saved_a', poem: '候鸟排成人字\n把我的问候带走\n往更南的南方'),
        _letterJson('saved_b', signature: '赶海的人'),
      ]),
    ]);

    await c.read(scripbookControllerProvider.notifier).start();

    final state = c.read(scripbookControllerProvider);
    expect(state.phase, ScripbookPhase.ready);
    expect(state.items, hasLength(2));
    // 有诗 → 逐行；无诗 → 首个文字块预览（共享 letter_preview 口径）
    expect(state.items[0].poemLines, hasLength(3));
    expect(state.items[1].poemLines, isEmpty);
    expect(state.items[1].previewText, contains('浪来过两次'));
    expect(state.items[0].placeLabel, '浙江 · 舟山');
    expect(state.items[0].timeLabel, contains('小时前'));
  });

  test('一封都没有：empty 态', () async {
    final c = container([_page(const [])]);

    await c.read(scripbookControllerProvider.notifier).start();

    expect(c.read(scripbookControllerProvider).phase, ScripbookPhase.empty);
  });

  test('拉取失败：error 态，打的是 /v1/me/scripbook', () async {
    final c = container([ScriptedResponse.fail(_server('/v1/me/scripbook'))]);

    await c.read(scripbookControllerProvider.notifier).start();

    expect(c.read(scripbookControllerProvider).phase, ScripbookPhase.error);
    expect(adapter.requests.single.uri.path, '/v1/me/scripbook');
  });

  test('移出成功：DELETE 命中，本地移除并提示；移出最后一封转 empty', () async {
    final c = container([
      _page([_letterJson('saved_a')]),
      const ScriptedResponse.ok(204),
    ]);
    final controller = c.read(scripbookControllerProvider.notifier);
    await controller.start();

    await controller.remove('saved_a');

    final state = c.read(scripbookControllerProvider);
    expect(state.items, isEmpty);
    expect(state.phase, ScripbookPhase.empty);
    expect(state.notice?.message, '已经把它放归风里');

    final request = adapter.requests.last;
    expect(request.method, 'DELETE');
    expect(request.uri.path, '/v1/me/scripbook/saved_a');
  });

  test('移出失败：列表原样保留，只发失败提示，不抛错', () async {
    final c = container([
      _page([_letterJson('saved_a'), _letterJson('saved_b')]),
      ScriptedResponse.fail(_server('/v1/me/scripbook/saved_a')),
    ]);
    final controller = c.read(scripbookControllerProvider.notifier);
    await controller.start();

    await controller.remove('saved_a');

    final state = c.read(scripbookControllerProvider);
    expect(state.phase, ScripbookPhase.ready);
    expect([for (final item in state.items) item.id], ['saved_a', 'saved_b']);
    expect(state.notice?.message, '没能移出，稍后再试');
  });

  test('静默刷新成功：列表原位替换，不清相位不闪加载态', () async {
    final c = container([
      _page([_letterJson('saved_a')]),
      _page([_letterJson('saved_c', poem: '候鸟排成人字\n把我的问候带走\n往更南的南方')]),
    ]);
    final controller = c.read(scripbookControllerProvider.notifier);
    await controller.start();

    await controller.refresh();

    final state = c.read(scripbookControllerProvider);
    expect(state.phase, ScripbookPhase.ready);
    expect(state.items.single.id, 'saved_c');
  });

  test('静默刷新失败：手里有列表就当没发生（保持原状，不出错误态）', () async {
    final c = container([
      _page([_letterJson('saved_a')]),
      ScriptedResponse.fail(_server('/v1/me/scripbook')),
    ]);
    final controller = c.read(scripbookControllerProvider.notifier);
    await controller.start();

    await controller.refresh();

    final state = c.read(scripbookControllerProvider);
    expect(state.phase, ScripbookPhase.ready);
    expect(state.items.single.id, 'saved_a');
  });

  test('静默刷新失败且无可展示内容：落 error 态', () async {
    final c = container([ScriptedResponse.fail(_server('/v1/me/scripbook'))]);

    await c.read(scripbookControllerProvider.notifier).refresh();

    expect(c.read(scripbookControllerProvider).phase, ScripbookPhase.error);
  });
}
