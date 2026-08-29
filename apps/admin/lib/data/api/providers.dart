/// 手写 provider（与 apps/app 同款：不用 codegen）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_store.dart';
import 'admin_api.dart';
import 'api_client.dart';

/// 测试 override 成 MemoryAdminSessionStore。
final adminSessionStoreProvider = Provider<AdminSessionStore>(
  (ref) => createSessionStore(),
);

/// 401 回调由 router 侧在消费时挂（见 app/router.dart 的 redirect 监听）。
final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('在 main.dart 用 overrideWithValue 注入');
});

final adminApiProvider = Provider<AdminApi>(
  (ref) => AdminApi(ref.watch(apiClientProvider)),
);
