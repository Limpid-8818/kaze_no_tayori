/// Web 实现：window.sessionStorage（标签页级，关页即失效）。
library;

import 'package:web/web.dart' as web;

import 'admin_session.dart';

AdminSessionStore createSessionStore() => WebSessionAdminSessionStore();

class WebSessionAdminSessionStore implements AdminSessionStore {
  static const _key = 'kaze_admin_token';

  @override
  Future<String?> read() async {
    final value = web.window.sessionStorage.getItem(_key);
    return value == null || value.isEmpty ? null : value;
  }

  @override
  Future<void> write(String token) async {
    web.window.sessionStorage.setItem(_key, token);
  }

  @override
  Future<void> clear() async {
    web.window.sessionStorage.removeItem(_key);
  }
}
