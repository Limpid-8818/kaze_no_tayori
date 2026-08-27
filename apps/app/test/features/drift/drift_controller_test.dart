/// 漂流控制器测试：抽取→封筒、池空→叙事态、换一封失败留桌、连续交换。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/data/api/api_client.dart';
import 'package:kazenotayori/data/api/providers.dart';
import 'package:kazenotayori/features/drift/drift_controller.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/scripted_adapter.dart';

Map<String, dynamic> _letterJson(String id) => {
  'id': id,
  'blocks': const [
    {'type': 'text', 'text': '傍晚的海边风很大'},
  ],
  'poem': '风穿过堤岸\n把下午吹得很轻\n浪只说了一半',
  'addressee': '拾到它的人',
  'theme_id': 'natsu',
  'delivery_mode': 'drift',
  'place_label': '浙江 · 舟山',
  'weather': const {'text': '多云', 'temp_c': 26.0},
  'parent_letter_id': null,
  'counts': const {
    'read': 0,
    'resonance': 1,
    'voice': 0,
    'reply': 0,
    'saved': 0,
  },
  'created_at': '2026-08-24T10:00:00Z',
};

DioException _driftPoolEmpty() => DioException(
  requestOptions: RequestOptions(
    path: '/v1/drift/next',
    baseUrl: 'http://test',
  ),
  response: Response(
    requestOptions: RequestOptions(
      path: '/v1/drift/next',
      baseUrl: 'http://test',
    ),
    statusCode: 404,
    data: {
      'error': {'code': 'drift_pool_empty', 'message': '此刻还没有漂来的信'},
    },
  ),
);

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

ProviderContainer _container(List<ScriptedResponse> script) {
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(
        ApiClient(
          dio: Dio(
            BaseOptions(
              baseUrl: 'http://test',
              contentType: Headers.jsonContentType,
            ),
          )..httpClientAdapter = ScriptedAdapter(script),
          store: fakeSecureStore(),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('抽中：进入 drawn，封面映射宛名/地点/天气/种子', () async {
    final c = _container([ScriptedResponse.ok(200, _letterJson('letter_a'))]);

    await c.read(driftControllerProvider.notifier).draw();

    final state = c.read(driftControllerProvider);
    expect(state.phase, DriftPhase.drawn);
    expect(state.view?.id, 'letter_a');
    expect(state.view?.seedId, 'letter_a');
    expect(state.view?.addressee, '拾到它的人');
    expect(state.view?.place, '浙江 · 舟山');
    expect(state.view?.weather, '多云 26°');
  });

  test('池空：叙事态而非错误', () async {
    final c = _container([ScriptedResponse.fail(_driftPoolEmpty())]);

    await c.read(driftControllerProvider.notifier).draw();

    expect(c.read(driftControllerProvider).phase, DriftPhase.empty);
  });

  test('首次抽取的网络错误：error 态（可再试一次）', () async {
    final c = _container([ScriptedResponse.fail(_server('/v1/drift/next'))]);

    await c.read(driftControllerProvider.notifier).draw();

    expect(c.read(driftControllerProvider).phase, DriftPhase.error);
  });

  test('换一封失败：旧封筒留在桌上，notice 提示而不掀桌', () async {
    final c = _container([
      ScriptedResponse.ok(200, _letterJson('letter_a')),
      ScriptedResponse.fail(_server('/v1/drift/next')),
    ]);
    final controller = c.read(driftControllerProvider.notifier);
    await controller.draw();
    expect(c.read(driftControllerProvider).view?.id, 'letter_a');

    await controller.draw();

    final state = c.read(driftControllerProvider);
    expect(state.phase, DriftPhase.drawn);
    expect(state.view?.id, 'letter_a');
    expect(state.notice?.message, '换一封没有成功');
  });

  test('换一封成功：新信上桌', () async {
    final c = _container([
      ScriptedResponse.ok(200, _letterJson('letter_a')),
      ScriptedResponse.ok(200, _letterJson('letter_b')),
    ]);
    final controller = c.read(driftControllerProvider.notifier);
    await controller.draw();

    await controller.draw();

    expect(c.read(driftControllerProvider).view?.id, 'letter_b');
  });

  test('重进重置：reset 回到第一幕，桌面清空', () async {
    final c = _container([ScriptedResponse.ok(200, _letterJson('letter_a'))]);
    final controller = c.read(driftControllerProvider.notifier);
    await controller.draw();
    expect(c.read(driftControllerProvider).phase, DriftPhase.drawn);

    controller.reset();

    final state = c.read(driftControllerProvider);
    expect(state.phase, DriftPhase.idle);
    expect(state.view, isNull);
  });
}
