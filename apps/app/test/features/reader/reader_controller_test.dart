/// ReaderController 单测：加载状态机、markRead 静默、共鸣乐观/校正/回滚、举报。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/data/api/api_client.dart';
import 'package:kazenotayori/data/api/providers.dart';
import 'package:kazenotayori/features/reader/reader_controller.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/scripted_adapter.dart';

Map<String, dynamic> _letterJson() => {
  'id': 'letter_1',
  'blocks': const [
    {'type': 'text', 'text': '你好'},
    {'type': 'photo', 'ref': 'https://x/img.jpg', 'mood': 'backlit'},
  ],
  'theme_id': 'natsu',
  'delivery_mode': 'drift',
  'place_label': '浙江 · 舟山',
  'weather': const {'text': '多云', 'temp_c': 26.0},
  'signature': '赶海的人',
  'parent_letter_id': null,
  'counts': const {
    'read': 3,
    'resonance': 2,
    'voice': 0,
    'reply': 0,
    'saved': 0,
  },
  'created_at': '2026-08-26T10:00:00Z',
};

DioException _notFound(String path) => DioException(
  requestOptions: RequestOptions(path: path, baseUrl: 'http://test'),
  response: Response(
    requestOptions: RequestOptions(path: path, baseUrl: 'http://test'),
    statusCode: 404,
    data: {
      'error': {'code': 'letter_not_found', 'message': 'x'},
    },
  ),
);

DioException _server(String path) => DioException(
  requestOptions: RequestOptions(path: path, baseUrl: 'http://test'),
  response: Response(
    requestOptions: RequestOptions(path: path, baseUrl: 'http://test'),
    statusCode: 500,
    data: {
      'error': {'code': 'internal', 'message': 'x'},
    },
  ),
);

class _Harness {
  _Harness(List<ScriptedResponse> script) : adapter = ScriptedAdapter(script) {
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          ApiClient(dio: _dio(adapter), store: fakeSecureStore()),
        ),
      ],
    );
  }

  final ScriptedAdapter adapter;
  late final ProviderContainer container;

  static Dio _dio(ScriptedAdapter adapter) {
    return Dio(
      BaseOptions(baseUrl: 'http://test', contentType: Headers.jsonContentType),
    )..httpClientAdapter = adapter;
  }

  ReaderController get controller =>
      container.read(readerControllerProvider.notifier);
  ReaderState get state => container.read(readerControllerProvider);

  void dispose() => container.dispose();
}

void main() {
  test('加载成功：ready + 视图就绪 + markRead 恰好一次', () async {
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson()),
      const ScriptedResponse.ok(204),
    ]);
    await h.controller.start('letter_1');

    expect(h.state.phase, ReaderPhase.ready);
    expect(h.state.view?.id, 'letter_1');
    expect(h.state.resonanceCount, 2);

    final paths = h.adapter.requests.map((r) => r.uri.path).toList();
    expect(paths, ['/v1/letters/letter_1', '/v1/letters/letter_1/read']);
    h.dispose();
  });

  test('404 → notFound 态（不再发 markRead）', () async {
    final h = _Harness([ScriptedResponse.fail(_notFound('/v1/letters/x'))]);
    await h.controller.start('x');
    expect(h.state.phase, ReaderPhase.notFound);
    expect(h.adapter.requests, hasLength(1));
    h.dispose();
  });

  test('服务错误 → error 态，可重试', () async {
    final h = _Harness([
      ScriptedResponse.fail(_server('/v1/letters/letter_1')),
      ScriptedResponse.ok(200, _letterJson()),
      const ScriptedResponse.ok(204),
    ]);
    await h.controller.start('letter_1');
    expect(h.state.phase, ReaderPhase.error);

    await h.controller.retry();
    expect(h.state.phase, ReaderPhase.ready);
    h.dispose();
  });

  test('markRead 失败不阻断阅读（ready 保持）', () async {
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson()),
      ScriptedResponse.fail(_server('/v1/letters/letter_1/read')),
    ]);
    await h.controller.start('letter_1');
    expect(h.state.phase, ReaderPhase.ready);
    expect(h.state.notice, isNull);
    h.dispose();
  });

  test('共鸣：乐观 +1 → 服务端计数校正；二次调用被忽略', () async {
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson()),
      const ScriptedResponse.ok(204),
      ScriptedResponse.ok(201, {'resonance_count': 7}),
    ]);
    await h.controller.start('letter_1');

    await h.controller.resonate();
    // 乐观位在校正前也应为 resonated（此处等待完成后已校正）
    expect(h.state.resonated, isTrue);
    expect(h.state.resonanceCount, 7);

    await h.controller.resonate(); // 一次性：忽略
    expect(h.adapter.requests, hasLength(3));
    h.dispose();
  });

  test('共鸣失败：回滚计数与落章，弹 notice', () async {
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson()),
      const ScriptedResponse.ok(204),
      ScriptedResponse.fail(_server('/v1/letters/letter_1/resonance')),
    ]);
    await h.controller.start('letter_1');

    await h.controller.resonate();
    expect(h.state.resonated, isFalse);
    expect(h.state.resonanceCount, 2);
    expect(h.state.notice?.message, '没有成功，再试一次');
    h.dispose();
  });

  test('举报：204 → notice「已举报」', () async {
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson()),
      const ScriptedResponse.ok(204),
      const ScriptedResponse.ok(204),
    ]);
    await h.controller.start('letter_1');

    await h.controller.report(reason: '垃圾广告');
    expect(h.state.notice?.message, '已举报');
    final reportReq = h.adapter.requests.last;
    expect(reportReq.uri.path, '/v1/letters/letter_1/report');
    h.dispose();
  });
}
