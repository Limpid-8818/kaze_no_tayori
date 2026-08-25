import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/core/result.dart';
import 'package:kazenotayori/data/api/ai_api.dart';
import 'package:kazenotayori/data/api/api_client.dart';
import 'package:kazenotayori/data/api/catalog_api.dart';
import 'package:kazenotayori/data/api/discover_api.dart';
import 'package:kazenotayori/data/api/drift_api.dart';
import 'package:kazenotayori/data/api/geo_api.dart';
import 'package:kazenotayori/data/api/letters_api.dart';
import 'package:kazenotayori/data/api/me_api.dart';
import 'package:kazenotayori/data/api/uploads_api.dart';
import 'package:kazenotayori/data/models/catalog.dart';
import 'package:kazenotayori/data/models/letter.dart';
import 'package:kazenotayori/data/models/notification.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/scripted_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ApiClient clientWith(ScriptedAdapter adapter) => ApiClient(
    store: fakeSecureStore({'kaze.access_token': 'tok'}),
    dio: Dio(
      BaseOptions(baseUrl: 'http://test', contentType: Headers.jsonContentType),
    )..httpClientAdapter = adapter,
  );

  /// 一封最小合法 LetterPublic JSON。
  const letterJson = {
    'id': 'l-1',
    'blocks': [
      {'type': 'text', 'text': '海的彼岸'},
      {'type': 'photo', 'ref': 'http://img/1.jpg', 'mood': 'overexposed'},
    ],
    'poem': null,
    'theme_id': 'natsu',
    'theme_skin': {
      'stamp': 's-1',
      'decor': ['d-1'],
    },
    'music_ref': {'album': 'A', 'song': 'B', 'lyrics': 'C'},
    'place_label': 'Tokyo',
    'weather': {'text': '小雨', 'temp_c': 19.0},
    'tags': ['旅途'],
    'delivery_mode': 'drift',
    'parent_letter_id': null,
    'counts': {'read': 1, 'resonance': 2, 'voice': 0, 'reply': 0, 'saved': 0},
    'created_at': '2026-08-20T23:47:00+09:00',
  };

  test('LettersApi.create 解析 LetterOwned（含 status/lat/lon）', () async {
    final adapter = ScriptedAdapter([
      const ScriptedResponse.ok(201, {
        ...letterJson,
        'status': 'pending',
        'lat': 35.68,
        'lon': 139.76,
      }),
    ]);
    final api = LettersApi(clientWith(adapter));
    final owned = await api.create(
      LetterCreateRequest(
        blocks: const [LetterBlock(type: 'text', text: '海的彼岸')],
        themeId: 'natsu',
        deliveryMode: DeliveryMode.drift,
      ),
    );
    expect(owned.status, LetterStatus.pending);
    expect(owned.lat, 35.68);
    expect(owned.blocks.length, 2);
    // 请求体 snake_case 正确
    final body = adapter.requests.single.data as Map<String, dynamic>;
    expect(body['theme_id'], 'natsu');
    expect(body['delivery_mode'], 'drift');
  });

  test(
    'DriftApi.next：404 drift_pool_empty → ApiFailure(driftPoolEmpty)',
    () async {
      final adapter = ScriptedAdapter([
        ScriptedResponse.fail(
          DioException(
            requestOptions: RequestOptions(path: '/v1/drift/next'),
            response: Response(
              requestOptions: RequestOptions(path: '/v1/drift/next'),
              statusCode: 404,
              data: {
                'error': {'code': 'drift_pool_empty', 'message': 'x'},
              },
            ),
          ),
        ),
      ]);
      final api = DriftApi(clientWith(adapter));
      await expectLater(
        api.next(),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.driftPoolEmpty,
          ),
        ),
      );
    },
  );

  test('DiscoverApi.list：query 用 snake_case，解析 Page', () async {
    final adapter = ScriptedAdapter([
      const ScriptedResponse.ok(200, {
        'items': [letterJson],
        'next_cursor': null,
      }),
    ]);
    final api = DiscoverApi(clientWith(adapter));
    final page = await api.list(lat: 35.68, lon: 139.76, radiusM: 500);
    expect(page.items.single.id, 'l-1');
    expect(page.nextCursor, isNull);
    final query = adapter.requests.single.queryParameters;
    expect(query['radius_m'], 500);
    expect(query['lat'], 35.68);
  });

  test('MeApi.notifications 解析 Page<NotificationPublic>', () async {
    final adapter = ScriptedAdapter([
      const ScriptedResponse.ok(200, {
        'items': [
          {
            'id': 'n-1',
            'type': 'reply',
            'letter_id': 'l-2',
            'parent_letter_id': 'l-1',
            'parent_place_label': 'Tokyo',
            'is_read': false,
            'created_at': '2026-08-20T23:47:00+09:00',
          },
        ],
        'next_cursor': null,
      }),
    ]);
    final api = MeApi(clientWith(adapter));
    final page = await api.notifications(unreadOnly: true);
    final n = page.items.single;
    expect(n.type, NotificationType.reply);
    expect(n.letterId, 'l-2');
    expect(n.isRead, isFalse);
    expect(adapter.requests.single.queryParameters['unread_only'], true);
  });

  test('MeApi.markNotificationRead：204 空体不炸', () async {
    final adapter = ScriptedAdapter([const ScriptedResponse.ok(204)]);
    final api = MeApi(clientWith(adapter));
    await api.markNotificationRead('n-1'); // 不抛即过
  });

  test('AiApi.polish：503 feature_disabled → isDegradable', () async {
    final adapter = ScriptedAdapter([
      ScriptedResponse.fail(
        DioException(
          requestOptions: RequestOptions(path: '/v1/ai/polish'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/ai/polish'),
            statusCode: 503,
            data: {
              'error': {'code': 'feature_disabled', 'message': 'x'},
            },
          ),
        ),
      ),
    ]);
    final api = AiApi(clientWith(adapter));
    try {
      await api.polish('内容');
      fail('应抛 ApiFailure');
    } on ApiFailure catch (e) {
      expect(e.isDegradable, isTrue); // UI 应降级到纯手动，不弹红错
    }
  });

  test('UploadsApi.uploadImage 返回 url', () async {
    final adapter = ScriptedAdapter([
      const ScriptedResponse.ok(201, {'url': 'http://img/x.jpg'}),
    ]);
    final api = UploadsApi(clientWith(adapter));
    final res = await api.uploadImage(
      filename: 'x.jpg',
      bytes: [1, 2],
      contentType: 'image/jpeg',
    );
    expect(res.url, 'http://img/x.jpg');
  });

  test('CatalogApi 解析裸数组（无 Page 包装）', () async {
    final adapter = ScriptedAdapter([
      const ScriptedResponse.ok(200, [
        {
          'id': 'natsu',
          'name': '夏の手紙',
          'assets': {
            'stamp': ['s-1'],
          },
          'is_default': true,
        },
      ]),
      const ScriptedResponse.ok(200, [
        {'id': 'journey', 'name': '旅途', 'color': '#FF6B6B'},
      ]),
    ]);
    final api = CatalogApi(clientWith(adapter));
    final themes = await api.themes();
    final tags = await api.tags();
    expect(
      themes.single,
      isA<ThemePublic>().having((t) => t.id, 'id', 'natsu'),
    );
    expect(tags.single.color, '#FF6B6B');
  });

  test('CatalogApi 遇到坏项时报 invalidResponse，不静默过滤', () async {
    final adapter = ScriptedAdapter([
      const ScriptedResponse.ok(200, [
        {'id': 'natsu', 'name': '夏の手紙', 'assets': {}, 'is_default': true},
        'bad-item',
      ]),
    ]);

    await expectLater(
      CatalogApi(clientWith(adapter)).themes(),
      throwsA(
        isA<ApiFailure>().having(
          (error) => error.kind,
          'kind',
          ApiErrorKind.invalidResponse,
        ),
      ),
    );
  });

  test('GeoApi 解析城市级地点；服务降级时返回 null', () async {
    final adapter = ScriptedAdapter([
      const ScriptedResponse.ok(200, {'place_label': '福建省·厦门市'}),
      ScriptedResponse.fail(
        DioException(
          requestOptions: RequestOptions(path: '/v1/geo/reverse'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/geo/reverse'),
            statusCode: 503,
          ),
        ),
      ),
    ]);
    final api = GeoApi(clientWith(adapter));

    expect(await api.reverse(24.48, 118.09), '福建省·厦门市');
    expect(await api.reverse(24.48, 118.09), isNull);
  });

  test('LettersApi.addResonance：resonance_count snake_case 映射', () async {
    final adapter = ScriptedAdapter([
      const ScriptedResponse.ok(200, {'resonance_count': 4}),
    ]);
    final api = LettersApi(clientWith(adapter));
    final res = await api.addResonance('l-1', note: '接住了');
    expect(res.resonanceCount, 4);
    final body = adapter.requests.single.data as Map<String, dynamic>;
    expect(body['note'], '接住了');
  });
}
