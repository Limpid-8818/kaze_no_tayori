import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_secure_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ensureDeviceId 首次生成合法 UUIDv4 并持久化', () async {
    final store = fakeSecureStore();
    final id = await store.ensureDeviceId();
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(id),
      isTrue,
      reason: '$id 应为合法 UUIDv4',
    );
    // 已写入底层存储（下次冷启动可读）
    expect(fakeStorageData().containsKey('kaze.device_id'), isTrue);
  });

  test('ensureDeviceId 幂等：再次调用返回同一个 id', () async {
    final store = fakeSecureStore();
    final first = await store.ensureDeviceId();
    final second = await store.ensureDeviceId();
    expect(second, first);
  });

  test('readDeviceId / writeDeviceId / clear 基本面', () async {
    final store = fakeSecureStore();
    expect(await store.readDeviceId(), isNull);
    await store.writeDeviceId('abc');
    expect(await store.readDeviceId(), 'abc');
    await store.clear();
    expect(await store.readDeviceId(), isNull);
  });
}
