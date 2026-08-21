/// 测试用 SecureStore：内存 Map 做后端。
///
/// 用包官方的 TestFlutterSecureStoragePlatform（内存实现）换掉全局
/// platform instance——比子类化 FlutterSecureStorage 稳（它的 read/write
/// 签名带六个平台 options 参数，且真正干活的是 _platform）。
///
/// 注意：platform instance 是全局单例，测试里用 setUp 换上、不还原
/// 也可以（每个测试重新给一份空 data 即可）。
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:kazenotayori/data/local/secure_store.dart';

/// 返回一个接在全新内存存储上的 [SecureStore]，并顺手把
/// 全局 platform instance 换成同一份（FlutterSecureStorage 内部
/// 直读该单例，两边必须同源）。
SecureStore fakeSecureStore([Map<String, String>? initial]) {
  final data = initial ?? <String, String>{};
  FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
    data,
  );
  return SecureStore(storage: const FlutterSecureStorage());
}

/// 暴露同一份内存数据，供断言读。
Map<String, String> fakeStorageData() {
  final platform = FlutterSecureStoragePlatform.instance;
  return (platform as TestFlutterSecureStoragePlatform).data;
}
