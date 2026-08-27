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
    expect(me['items'], isEmpty);
    expect(me['next_cursor'], isNull);
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
