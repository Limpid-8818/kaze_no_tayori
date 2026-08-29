/// 条件导出：抽象/内存假体恒可见；createSessionStore 按平台切换。
library;

export 'admin_session.dart' show AdminSessionStore, MemoryAdminSessionStore;
export 'session_store_noop.dart'
    if (dart.library.html) 'session_store_web.dart';
