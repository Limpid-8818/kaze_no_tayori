/// 管理端会话状态（唯一所有者）。
///
/// token 的持久层是 sessionStorage；这里持有内存镜像供 router redirect
/// 同步判断。401 由 ApiClient 回调 [handleUnauthorized] → 清会话 →
/// refreshListenable 通知 router 踢回 /login。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session/admin_session.dart';

/// main.dart 用 overrideWithValue 注入（测试同样）。
final adminAuthProvider = Provider<AdminAuth>(
  (ref) => throw UnimplementedError('在 main.dart 用 overrideWithValue 注入'),
);

class AdminAuth extends ChangeNotifier {
  AdminAuth(this._store);

  final AdminSessionStore _store;

  String? _token;
  bool ready = false;

  String? get token => _token;
  bool get loggedIn => _token != null;

  /// 冷启动恢复（sessionStorage 关页即清，通常为空）。
  Future<void> restore() async {
    _token = await _store.read();
    ready = true;
    notifyListeners();
  }

  Future<void> signIn(String token) async {
    await _store.write(token);
    _token = token;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _store.clear();
    _token = null;
    notifyListeners();
  }

  /// ApiClient 401 回调入口（fire-and-forget，不阻塞错误传播）。
  void handleUnauthorized() {
    if (_token == null) return;
    signOut();
  }
}
