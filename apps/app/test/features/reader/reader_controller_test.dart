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

Map<String, dynamic> _letterJson({
  String id = 'letter_1',
  bool meResonated = false,
}) => {
  'id': id,
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
  'me_resonated': meResonated,
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

  static const _id = 'letter_1';

  final ScriptedAdapter adapter;
  late final ProviderContainer container;

  static Dio _dio(ScriptedAdapter adapter) {
    return Dio(
      BaseOptions(baseUrl: 'http://test', contentType: Headers.jsonContentType),
    )..httpClientAdapter = adapter;
  }

  /// family 按 letterId 分实例：getter 取主测信，叠栈场景用 controllerOf。
  ReaderController get controller =>
      container.read(readerControllerProvider(_id).notifier);
  ReaderController controllerOf(String id) =>
      container.read(readerControllerProvider(id).notifier);
  ReaderState stateOf(String id) =>
      container.read(readerControllerProvider(id));
  ReaderState get state => stateOf(_id);

  void dispose() => container.dispose();
}

void main() {
  test('加载成功：ready + 视图就绪 + markRead 恰好一次', () async {
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson()),
      const ScriptedResponse.ok(204),
    ]);
    await h.controller.start();

    expect(h.state.phase, ReaderPhase.ready);
    expect(h.state.view?.id, 'letter_1');
    expect(h.state.resonanceCount, 2);

    final paths = h.adapter.requests.map((r) => r.uri.path).toList();
    expect(paths, ['/v1/letters/letter_1', '/v1/letters/letter_1/read']);
    h.dispose();
  });

  test('404 → notFound 态（不再发 markRead）', () async {
    final h = _Harness([ScriptedResponse.fail(_notFound('/v1/letters/x'))]);
    await h.controller.start();
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
    await h.controller.start();
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
    await h.controller.start();
    expect(h.state.phase, ReaderPhase.ready);
    expect(h.state.notice, isNull);
    h.dispose();
  });

  test('已共鸣播种：me_resonated 随详情加载点亮（重进章常亮）', () async {
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson(meResonated: true)),
      const ScriptedResponse.ok(204),
    ]);
    await h.controller.start();

    expect(h.state.phase, ReaderPhase.ready);
    expect(h.state.resonated, isTrue);
    expect(h.state.resonanceCount, 2);
    h.dispose();
  });

  test('共鸣：乐观 +1 → 服务端计数校正；二次调用被忽略', () async {
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson()),
      const ScriptedResponse.ok(204),
      ScriptedResponse.ok(201, {'resonance_count': 7}),
    ]);
    await h.controller.start();

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
    await h.controller.start();

    await h.controller.resonate();
    expect(h.state.resonated, isFalse);
    expect(h.state.resonanceCount, 2);
    expect(h.state.notice?.message, '没有成功，再试一次');
    h.dispose();
  });

  test('记入抄本：POST 带 letter_id，成功 notice「已收进抄本」', () async {
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson()),
      const ScriptedResponse.ok(204),
      const ScriptedResponse.ok(204),
    ]);
    await h.controller.start();

    await h.controller.saveToScripbook();

    expect(h.state.notice?.message, '已收进抄本');
    final request = h.adapter.requests.last;
    expect(request.method, 'POST');
    expect(request.uri.path, '/v1/me/scripbook');
    expect((request.data as Map<String, dynamic>)['letter_id'], 'letter_1');
    h.dispose();
  });

  test('记入抄本失败：notice 提示，phase 保持 ready 不抛错', () async {
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson()),
      const ScriptedResponse.ok(204),
      ScriptedResponse.fail(_server('/v1/me/scripbook')),
    ]);
    await h.controller.start();

    await h.controller.saveToScripbook();

    expect(h.state.phase, ReaderPhase.ready);
    expect(h.state.notice?.message, '没能收进抄本，再试一次');
    h.dispose();
  });

  test('举报：204 → notice「已举报」', () async {
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson()),
      const ScriptedResponse.ok(204),
      const ScriptedResponse.ok(204),
    ]);
    await h.controller.start();

    await h.controller.report(reason: '垃圾广告');
    expect(h.state.notice?.message, '已举报');
    final reportReq = h.adapter.requests.last;
    expect(reportReq.uri.path, '/v1/letters/letter_1/report');
    h.dispose();
  });

  test('叠栈互不污染：看原信叠开第二封，先前的信不被覆盖或清空', () async {
    // 曾是全局单例 provider 的回归场景：第二个读信页 start() 会把共享
    // 状态硬重置，栈下原信页被污染成 loading/空态且返回后无人恢复。
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson()),
      const ScriptedResponse.ok(204),
      ScriptedResponse.ok(200, _letterJson(id: 'letter_0')),
      const ScriptedResponse.ok(204),
    ]);
    await h.controller.start(); // 原信页 letter_1 → ready

    await h.controllerOf('letter_0').start(); // 叠开的原信 letter_0 → ready

    expect(h.state.phase, ReaderPhase.ready);
    expect(h.state.view?.id, 'letter_1');
    expect(h.stateOf('letter_0').phase, ReaderPhase.ready);
    expect(h.stateOf('letter_0').view?.id, 'letter_0');
    h.dispose();
  });

  test('叠栈互不污染：第二封 404，先前的信仍保持 ready', () async {
    final h = _Harness([
      ScriptedResponse.ok(200, _letterJson()),
      const ScriptedResponse.ok(204),
      ScriptedResponse.fail(_notFound('/v1/letters/x')),
    ]);
    await h.controller.start();

    await h.controllerOf('letter_gone').start();

    expect(h.state.phase, ReaderPhase.ready);
    expect(h.state.view?.id, 'letter_1');
    expect(h.stateOf('letter_gone').phase, ReaderPhase.notFound);
    h.dispose();
  });
}
