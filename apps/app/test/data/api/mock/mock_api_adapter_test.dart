/// MockApiAdapter 路由表测试：写信闭环触达的每个端点都吐契约内形状。
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/data/api/mock/mock_api_adapter.dart';

Dio _dio() {
  return Dio(
    BaseOptions(baseUrl: 'http://test', contentType: Headers.jsonContentType),
  )..httpClientAdapter = MockApiAdapter();
}

Future<Map<String, dynamic>> _decode(Future<Response<dynamic>> future) async {
  final resp = await future;
  return Map<String, dynamic>.from(resp.data as Map);
}

void main() {
  test('设备静默登录换到 JWT', () async {
    final body = await _decode(
      _dio().post('/v1/auth/device', data: {'device_id': 'uuid-1'}),
    );
    expect(body['access_token'], isNotEmpty);
    expect(body['token_type'], 'bearer');
    expect(body['user_id'], isNotNull);
  });
  test('图片上传拿到 URL', () async {
    final body = await _decode(
      _dio().post('/v1/uploads/images', data: FormData.fromMap({'file': 'x'})),
    );
    expect(body['url'], startsWith('https://'));
  });
  test('寄信回显请求体，状态 pending（审核决定公开与否）', () async {
    final body = await _decode(
      _dio().post(
        '/v1/letters',
        data: {
          'blocks': [
            {'type': 'text', 'text': '你好'},
          ],
          'theme_id': 'natsu',
          'delivery_mode': 'drift',
          'signature': '小海',
        },
      ),
    );
    expect(body['status'], 'pending');
    expect(body['theme_id'], 'natsu');
    expect(body['delivery_mode'], 'drift');
    expect(body['blocks'], [
      {'type': 'text', 'text': '你好'},
    ]);
    expect(body['counts'], containsPair('resonance', 0));
  });
  test('回信端点同形（parent 挂路径）', () async {
    final body = await _decode(
      _dio().post(
        '/v1/letters/abc/replies',
        data: {
          'blocks': [
            {'type': 'text', 'text': '回你'},
          ],
          'theme_id': 'natsu',
          'delivery_mode': 'stay',
          'lat': 30.27,
          'lon': 120.15,
        },
      ),
    );
    expect(body['status'], 'pending');
    expect(body['lat'], 30.27);
  });
  test('天气/逆地理/我的信是可用的罐头', () async {
    final weather = await _decode(
      _dio().get('/v1/weather/now', queryParameters: {'lat': 30, 'lon': 120}),
    );
    expect(weather['text'], isNotEmpty);
    final geo = await _decode(
      _dio().get('/v1/geo/reverse', queryParameters: {'lat': 30, 'lon': 120}),
    );
    expect(geo['place_label'], isNotNull);
    final me = await _decode(_dio().get('/v1/me/letters'));
    // F6：四种状态各一封种子信，徽标与下架链路可离线走通
    final items = List<Map<String, dynamic>>.from(me['items'] as List);
    expect(items, hasLength(4));
    expect([
      for (final item in items) item['status'],
    ], containsAll(['pending', 'public', 'rejected', 'taken_down']));
    expect(me['next_cursor'], isNull);
  });
  test('下架我的信：DELETE 置 taken_down 非硬删，未知 id 404（F6）', () async {
    final dio = _dio();
    final before = await _decode(dio.get('/v1/me/letters'));
    await expectLater(dio.delete('/v1/me/letters/mock_mine_1'), completes);

    final after = await _decode(dio.get('/v1/me/letters'));
    final flipped = [
      for (final item in (after['items'] as List))
        Map<String, dynamic>.from(item),
    ].firstWhere((item) => item['id'] == 'mock_mine_1');
    expect(flipped['status'], 'taken_down');
    // 列表不移除——下架后仍能在「我的信」里看到下场
    expect(after['items'], hasLength((before['items'] as List).length));

    await expectLater(
      dio.delete('/v1/me/letters/mock_unknown'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          404,
        ),
      ),
    );
  });
  test('抄本（F7）：初始带诗/无诗各一封；收进去重且最新在前，移出/未知 id 404', () async {
    final dio = _dio();
    final before = await _decode(dio.get('/v1/me/scripbook'));
    final beforeItems = List<Map<String, dynamic>>.from(
      before['items'] as List,
    );
    expect(before['next_cursor'], isNull);
    expect(beforeItems, hasLength(2));
    // 摘要卡两种形态都在场：一封有诗、一封无诗
    expect([
      for (final item in beforeItems) (item['poem'] as String?)?.isNotEmpty,
    ], contains(true));

    // 收进漂流种子信：重复收不膨胀列表，最新收进的排最前
    await expectLater(
      dio.post('/v1/me/scripbook', data: {'letter_id': 'mock_drift_2'}),
      completes,
    );
    await dio.post('/v1/me/scripbook', data: {'letter_id': 'mock_drift_2'});
    final after = await _decode(dio.get('/v1/me/scripbook'));
    final ids = [for (final item in after['items'] as List) item['id']];
    expect(ids, hasLength(3));
    expect(ids.first, 'mock_drift_2');

    await expectLater(
      dio.post('/v1/me/scripbook', data: {'letter_id': 'mock_unknown'}),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          404,
        ),
      ),
    );
    await expectLater(dio.delete('/v1/me/scripbook/mock_drift_2'), completes);
    await expectLater(
      dio.delete('/v1/me/scripbook/mock_unknown'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          404,
        ),
      ),
    );
  });
  test('未覆盖的路由 404 且带统一错误体（不静默成功）', () async {
    final dio = _dio();
    await expectLater(
      dio.get('/v1/whatever'),
      throwsA(
        isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 404)
            .having(
              (e) => (e.response?.data as Map)['error'],
              'error body',
              isA<Map>(),
            ),
      ),
    );
  });
}
