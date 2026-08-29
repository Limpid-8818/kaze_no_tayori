import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/admin_auth.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/api/api_client.dart';
import 'data/api/providers.dart';
import 'data/session/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = createSessionStore();
  final auth = AdminAuth(store);
  // 会话恢复不阻塞首帧；恢复完成 notifyListeners 会触发 router 重判 redirect
  auth.restore();
  final client = ApiClient(
    store: store,
    onUnauthorized: auth.handleUnauthorized,
  );
  runApp(
    ProviderScope(
      overrides: [
        adminSessionStoreProvider.overrideWithValue(store),
        adminAuthProvider.overrideWithValue(auth),
        apiClientProvider.overrideWithValue(client),
      ],
      child: const AdminApp(),
    ),
  );
}

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '风信 · 运营控制台',
      theme: AdminTheme.light(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
