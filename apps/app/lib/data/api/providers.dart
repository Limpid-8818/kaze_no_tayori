/// 数据层 providers。
///
/// 手写 Provider（无参无状态，不值得 codegen 往返）；F1 的 Notifier
/// 再上 @riverpod。main() 里用 overrideWithValue 保证启动实例与
/// provider 暴露的是同一个（token 写入后消费者立即受益）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/secure_store.dart';
import 'api_client.dart';
import 'ai_api.dart';
import 'auth_api.dart';
import 'catalog_api.dart';
import 'discover_api.dart';
import 'drift_api.dart';
import 'letters_api.dart';
import 'me_api.dart';
import 'uploads_api.dart';

final secureStoreProvider = Provider<SecureStore>((_) => SecureStore());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(store: ref.watch(secureStoreProvider)),
);

final authApiProvider = Provider(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
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

/// 脚手架期的连通性探针。功能开发完成后随 HealthCard 一起删掉。
final healthProvider = FutureProvider<String>((ref) async {
  final json = await ref.watch(apiClientProvider).getJson('/health');
  return json['status'] as String? ?? 'unknown';
});
