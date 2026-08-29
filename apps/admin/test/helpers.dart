/// 测试公共设施：带脚本 adapter 的 ProviderContainer。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaze_admin/app/admin_auth.dart';
import 'package:kaze_admin/data/api/api_client.dart';
import 'package:kaze_admin/data/api/providers.dart';
import 'package:kaze_admin/data/session/admin_session.dart';

import 'fakes/scripted_adapter.dart';

ProviderContainer makeContainer(
  ScriptedAdapter adapter, {
  MemoryAdminSessionStore? store,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://test',
      contentType: Headers.jsonContentType,
      validateStatus: (code) => code != null && code < 500,
    ),
  )..httpClientAdapter = adapter;
  final memStore = store ?? MemoryAdminSessionStore();
  final client = ApiClient(dio: dio, store: memStore);
  final auth = AdminAuth(memStore);
  final container = ProviderContainer(
    overrides: [
      adminSessionStoreProvider.overrideWithValue(memStore),
      adminAuthProvider.overrideWithValue(auth),
      apiClientProvider.overrideWithValue(client),
    ],
  );
  return container;
}

/// 管理端响应 JSON 工厂（test_admin 各文件共用）。
Map<String, dynamic> summaryJson({
  String id = 'l1',
  String status = 'pending',
  String mode = 'drift',
  String? place = '测试 · 种子镇',
  String? preview = '风把海的味道带来了',
}) => {
  'id': id,
  'status': status,
  'delivery_mode': mode,
  'place_label': place,
  'lat': null,
  'lon': null,
  'preview': preview,
  'counts': {'read': 3, 'resonance': 1, 'voice': 0, 'reply': 0, 'saved': 0},
  'created_at': '2026-08-29T10:00:00+00:00',
};

Map<String, dynamic> detailJson({
  String id = 'l1',
  String status = 'pending',
}) => {
  'id': id,
  'blocks': [
    {'type': 'text', 'text': '风把海的味道带来了'},
  ],
  'poem': null,
  'signature': '海边的人',
  'addressee': null,
  'theme_id': 'natsu',
  'theme_skin': null,
  'music_ref': null,
  'place_label': '测试 · 种子镇',
  'weather': {'text': '小雨', 'temp_c': 19.0, 'icon': 'rainy'},
  'tags': [],
  'delivery_mode': 'drift',
  'parent_letter_id': null,
  'counts': {'read': 3, 'resonance': 1, 'voice': 0, 'reply': 0, 'saved': 0},
  'lat': null,
  'lon': null,
  'me_resonated': false,
  'created_at': '2026-08-29T10:00:00+00:00',
  'status': status,
  'owner_user_id': '0b8f2e58-0000-0000-0000-000000000001',
};

Map<String, dynamic> statsJson() => {
  'letters_by_status': {'pending': 2, 'public': 5},
  'users_total': 7,
  'letters_7d': 3,
  'letters_30d': 6,
  'pool': {'drift_available': 4, 'stay_active': 1},
  'todo': {'pending_letters': 2, 'open_reports': 1, 'open_feedbacks': 0},
};

Map<String, dynamic> reportJson({String status = 'open'}) => {
  'id': 'r1',
  'letter': {
    'id': 'l1',
    'status': 'public',
    'delivery_mode': 'drift',
    'place_label': '测试 · 种子镇',
    'preview': '风把海的味道带来了',
  },
  'reporter_user_id': null,
  'reason': '不当内容',
  'detail': '测试举报',
  'status': status,
  'admin_note': null,
  'handled_at': null,
  'created_at': '2026-08-29T10:00:00+00:00',
};

Map<String, dynamic> feedbackJson({String status = 'open'}) => {
  'id': 'f1',
  'user_id': null,
  'category': 'bug',
  'content': '读信页图片偶尔不显示',
  'app_version': '1.2.0',
  'platform': 'android',
  'status': status,
  'admin_note': null,
  'handled_at': null,
  'created_at': '2026-08-29T10:00:00+00:00',
};
