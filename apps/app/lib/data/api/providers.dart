/// 数据层 providers。
///
/// 手写 Provider（无参无状态，不值得 codegen 往返）；F1 的 Notifier
/// 再上 @riverpod。main() 里用 overrideWithValue 保证启动实例与
/// provider 暴露的是同一个（token 写入后消费者立即受益）。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../local/secure_store.dart';
import 'api_client.dart';
import 'ai_api.dart';
import 'catalog_api.dart';
import 'discover_api.dart';
import 'drift_api.dart';
import 'feedback_api.dart';
import 'geo_api.dart';
import 'letters_api.dart';
import 'me_api.dart';
import 'mock/mock_api_adapter.dart';
import 'uploads_api.dart';
import 'weather_api.dart';

final secureStoreProvider = Provider<SecureStore>((_) => SecureStore());

/// 组装 ApiClient —— [Env.useMockApi] 在这里分叉。main() 的启动实例与
/// 本 provider 走同一函数，保证 mock 开关对两者一致。
ApiClient createApiClient({SecureStore? store}) {
  if (!Env.useMockApi) return ApiClient(store: store);
  return ApiClient(
    dio: _mockDio(),
    // 重绑用的裸 Dio 也要挂 mock，否则 401 重绑会打到真实网络
    rebindDio: _mockDio(),
    store: store,
  );
}

Dio _mockDio() {
  return Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
    ),
  )..httpClientAdapter = MockApiAdapter();
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => createApiClient(store: ref.watch(secureStoreProvider)),
);

final lettersApiProvider = Provider(
  (ref) => LettersApi(ref.watch(apiClientProvider)),
);
final driftApiProvider = Provider(
  (ref) => DriftApi(ref.watch(apiClientProvider)),
);
final discoverApiProvider = Provider(
  (ref) => DiscoverApi(ref.watch(apiClientProvider)),
);
final meApiProvider = Provider((ref) => MeApi(ref.watch(apiClientProvider)));
final aiApiProvider = Provider((ref) => AiApi(ref.watch(apiClientProvider)));
final uploadsApiProvider = Provider(
  (ref) => UploadsApi(ref.watch(apiClientProvider)),
);
final catalogApiProvider = Provider(
  (ref) => CatalogApi(ref.watch(apiClientProvider)),
);
final weatherApiProvider = Provider(
  (ref) => WeatherApi(ref.watch(apiClientProvider)),
);
final geoApiProvider = Provider((ref) => GeoApi(ref.watch(apiClientProvider)));
final feedbackApiProvider = Provider(
  (ref) => FeedbackApi(ref.watch(apiClientProvider)),
);
