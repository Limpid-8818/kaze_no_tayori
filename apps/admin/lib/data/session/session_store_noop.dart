/// 非 Web 平台缺省：内存实现。
library;

import 'admin_session.dart';

AdminSessionStore createSessionStore() => MemoryAdminSessionStore();
