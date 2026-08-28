/// WriteController 单测：光标分裂插入、照片顺序、校验镜像、提交契约、
/// 草稿保存与恢复。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/app/controllers/location_controller.dart';
import 'package:kazenotayori/data/api/api_client.dart';
import 'package:kazenotayori/data/api/providers.dart';
import 'package:kazenotayori/data/device/image_gateway.dart';
import 'package:kazenotayori/data/device/location_gateway.dart';
import 'package:kazenotayori/data/models/letter.dart';
import 'package:kazenotayori/features/write/draft_store.dart';
import 'package:kazenotayori/features/write/write_controller.dart';

import '../../fakes/fake_secure_store.dart';
import '../../fakes/scripted_adapter.dart';

/// 1×1 真 PNG（组件库 letters_test 同款字节，供渲染与嗅探两用）
final List<int> kTinyPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
]);

final List<int> kTinyJpeg = Uint8List.fromList([
  0xFF,
  0xD8,
  0xFF,
  0xE0,
  0x00,
  0x10,
  0x4A,
  0x46,
  0x49,
  0x46,
]);

class _FakeImageGateway implements ImageGateway {
  _FakeImageGateway(this.images);

  final List<PickedImage> images;
  var lastMaxCount = 0;

  @override
  Future<List<PickedImage>> pickImages({required int maxCount}) async {
    lastMaxCount = maxCount;
    return images;
  }
}

PickedImage _png() => PickedImage(bytes: List.of(kTinyPng), mime: 'image/png');

/// 可解析的 LetterOwned 罐头（status=pending，落库即结束）。
Map<String, dynamic> _letterOwnedJson(Map<String, dynamic> body) => {
  'id': 'letter_1',
  'blocks': body['blocks'] ?? const [],
  'theme_id': 'natsu',
  'delivery_mode': body['delivery_mode'] ?? 'drift',
  'counts': const {
    'read': 0,
    'resonance': 0,
    'voice': 0,
    'reply': 0,
    'saved': 0,
  },
  'created_at': '2026-08-26T10:00:00Z',
  'status': 'pending',
};

class _Harness {
  _Harness({
    List<PickedImage> images = const [],
    List<ScriptedResponse> script = const [],
  }) : adapter = ScriptedAdapter(script) {
    tempDir = Directory.systemTemp.createTempSync('kaze_write_test');
    container = ProviderContainer(
      overrides: [
        imageGatewayProvider.overrideWithValue(_FakeImageGateway(images)),
        draftStoreProvider.overrideWithValue(
          DraftStore(baseDirFactory: () async => tempDir),
        ),
        apiClientProvider.overrideWithValue(
          ApiClient(dio: _dio(adapter), store: fakeSecureStore()),
        ),
      ],
    );
    _subscription = container.listen(writeControllerProvider, (_, _) {});
  }

  final ScriptedAdapter adapter;
  late final Directory tempDir;
  late final ProviderContainer container;
  late final ProviderSubscription<WriteState> _subscription;

  static Dio _dio(ScriptedAdapter adapter) {
    return Dio(
      BaseOptions(baseUrl: 'http://test', contentType: Headers.jsonContentType),
    )..httpClientAdapter = adapter;
  }

  WriteController get controller =>
      container.read(writeControllerProvider.notifier);

  WriteState get state => container.read(writeControllerProvider);

  void stopListening() => _subscription.close();

  Future<void> dispose() async {
    _subscription.close();
    container.dispose();
    // Windows 下文件句柄释放有延迟，清理是尽力而为
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } on FileSystemException {
      // 留给系统临时目录清理
    }
  }

  /// 等异步链（真实文件 IO + 上传 + 微任务）跑完。用真实小延迟轮询，
  /// Duration.zero 只推微任务，不够 Windows 的文件系统调度。
  Future<void> settle() async {
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// 等防抖保存（500ms）真实触发。
  Future<void> flushDraft() async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    await settle();
  }
}

void main() {
  test('sniffImageMime 只认 jpeg/png/webp 的魔数', () {
    expect(sniffImageMime(kTinyJpeg), 'image/jpeg');
    expect(sniffImageMime(kTinyPng), 'image/png');
    expect(
      sniffImageMime([
        0x52,
        0x49,
        0x46,
        0x46,
        0,
        0,
        0,
        0,
        0x57,
        0x45,
        0x42,
        0x50,
      ]),
      'image/webp',
    );
    expect(sniffImageMime(<int>['h'.codeUnitAt(0), 'e'.codeUnitAt(0)]), isNull);
    expect(sniffImageMime(const []), isNull);
  });

  test('写信页离栈后释放 provider 并触发资源清理', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.controller.start();
    expect(harness.container.exists(writeControllerProvider), isTrue);

    harness.stopListening();
    await harness.container.pump();

    expect(harness.container.exists(writeControllerProvider), isFalse);
  });

  test('在光标处插入照片：文本段一分为二，照片夹中间，光标回断点', () async {
    final harness = _Harness(
      images: [_png(), _png()],
      script: [
        ScriptedResponse.ok(201, {'url': 'https://t/u1.jpg'}),
        ScriptedResponse.ok(201, {'url': 'https://t/u2.jpg'}),
      ],
    );
    addTearDown(harness.dispose);

    await harness.controller.start();
    harness.controller.updateText(0, '今天的风有些不一样，像某个下午的海');
    harness.controller.reportCursor(0, 10);
    await harness.controller.addPhotosAtCursor();
    await harness.settle();

    final state = harness.state;
    // [前半段, 照, 照, 后半段]
    expect(state.blocks.length, 4);
    expect((state.blocks[0] as WriteTextBlock).text, '今天的风有些不一样，');
    expect(state.blocks[1], isA<WritePhotoBlock>());
    expect(state.blocks[2], isA<WritePhotoBlock>());
    expect((state.blocks[3] as WriteTextBlock).text, '像某个下午的海');
    // 托盘按信内实际位置排序
    expect(state.photos.length, 2);
    expect(state.photos[0].remoteUrl, 'https://t/u1.jpg');
    expect(state.photos[1].remoteUrl, 'https://t/u2.jpg');
    // 上传按顺序
    expect(
      harness.adapter.requests.map((r) => r.path).toList(),
      everyElement('/v1/uploads/images'),
    );
    // 焦点请求落在后半段末尾
    expect(state.focusRequest?.blockId, (state.blocks[3] as WriteTextBlock).id);
  });

  test('无锚点时照片落在信末尾，且 blocks 仍以文本段收尾', () async {
    final harness = _Harness(
      images: [_png()],
      script: [
        ScriptedResponse.ok(201, {'url': 'https://t/u1.jpg'}),
      ],
    );
    addTearDown(harness.dispose);

    await harness.controller.start();
    harness.controller.updateText(0, '写在前面');
    await harness.controller.addPhotosAtCursor();
    await harness.settle();

    final blocks = harness.state.blocks;
    expect((blocks[0] as WriteTextBlock).text, '写在前面');
    expect(blocks[1], isA<WritePhotoBlock>());
    expect(blocks.last, isA<WriteTextBlock>());
    expect((blocks.last as WriteTextBlock).text, '');
  });

  test('照片到三张后拒绝再选并给出叙事提示', () async {
    final harness = _Harness(
      images: [_png(), _png(), _png()],
      script: [
        ScriptedResponse.ok(201, {'url': 'https://t/u1.jpg'}),
        ScriptedResponse.ok(201, {'url': 'https://t/u2.jpg'}),
        ScriptedResponse.ok(201, {'url': 'https://t/u3.jpg'}),
      ],
    );
    addTearDown(harness.dispose);

    await harness.controller.start();
    harness.controller.updateText(0, 'x');
    await harness.controller.addPhotosAtCursor();
    await harness.settle();
    expect(harness.state.photoCount, 3);

    await harness.controller.addPhotosAtCursor();
    expect(harness.state.notice?.message, '一封信最多夹三张照片');
  });

  test('移除照片会同步删掉草稿图片文件', () async {
    final harness = _Harness(
      images: [_png()],
      script: [
        ScriptedResponse.ok(201, {'url': 'https://t/u1.jpg'}),
      ],
    );
    addTearDown(harness.dispose);

    await harness.controller.start();
    harness.controller.updateText(0, 'x');
    await harness.controller.addPhotosAtCursor();
    await harness.settle();
    final photo = harness.state.photos.single;
    expect(File(photo.localPath).existsSync(), isTrue);

    await harness.controller.removePhoto(photo.id);
    expect(harness.state.photoCount, 0);
    expect(File(photo.localPath).existsSync(), isFalse);
  });

  test('留/投必选：不选就寄出会被拦下，不发请求', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.controller.start();
    harness.controller.updateText(0, '写了一句话');
    final owned = await harness.controller.send();

    expect(owned, isNull);
    expect(harness.state.notice?.message, '还没有选择寄往何处');
    expect(harness.adapter.requests, isEmpty);
  });

  test('stay 没有坐标不能寄出（只有地名不行）', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.controller.start();
    harness.controller.updateText(0, '写了一句话');
    harness.controller.setDelivery(DeliveryMode.stay);
    harness.controller.confirmDropPoint(lat: null, lon: null, label: '只有地名');

    final owned = await harness.controller.send();
    expect(owned, isNull);
    expect(harness.state.notice?.message, '留在这里需要先确定一个落点');
    expect(harness.adapter.requests, isEmpty);
  });

  test('寄出成功：契约正确、草稿清空、状态重置', () async {
    final harness = _Harness(
      script: [
        // confirmDropPoint 会先异步取一次天气（可降级），再到寄出
        ScriptedResponse.ok(200, {'text': '晴', 'temp_c': 27.5}),
        ScriptedResponse.ok(201, _letterOwnedJson({})),
      ],
    );
    addTearDown(harness.dispose);

    await harness.controller.start();
    harness.controller.updateText(0, '正文一句话');
    harness.controller.setSignature('  小海  ');
    harness.controller.setAddressee('远方的你');
    harness.controller.setDelivery(DeliveryMode.drift);
    harness.controller.confirmDropPoint(
      lat: 30.27,
      lon: 120.15,
      label: '浙江 · 杭州',
    );

    final owned = await harness.controller.send();

    expect(owned, isNotNull);
    expect(owned!.status.name, 'pending');
    // 请求体契约（第一条是落点触发的天气，取寄信那条）。
    // adapter 层的 data 尚未 JSON 序列化，blocks 是 LetterBlock 模型。
    final sent =
        harness.adapter.requests.lastWhere((r) => r.path == '/v1/letters').data
            as Map<String, dynamic>;
    expect(sent['theme_id'], 'natsu'); // P0 固定夏主题
    expect(sent['delivery_mode'], 'drift');
    expect(sent['signature'], '小海'); // trim 后
    expect(sent['addressee'], '远方的你');
    expect(sent['place_label'], '浙江 · 杭州');
    expect(sent['lat'], 30.27);
    expect(sent['lon'], 120.15);
    final sentBlocks = [
      for (final block in sent['blocks'] as List)
        (block as LetterBlock).toJson(),
    ];
    expect(sentBlocks, [
      {'type': 'text', 'text': '正文一句话'},
    ]);
    // 草稿与状态
    final draftLeft = await harness.container
        .read(draftStoreProvider)
        .loadJson('write');
    expect(draftLeft, isNull);
    expect(harness.state.textCharCount, 0);
    expect(harness.state.sending, isFalse);
  });

  test('寄出失败（服务端错误）会转成提示，sending 复位', () async {
    final harness = _Harness(
      script: [
        ScriptedResponse.fail(
          DioException(
            requestOptions: RequestOptions(path: '/v1/letters'),
            response: Response(
              requestOptions: RequestOptions(path: '/v1/letters'),
              statusCode: 500,
              data: {
                'error': {'code': 'internal', 'message': '服务器打了个盹'},
              },
            ),
          ),
        ),
      ],
    );
    addTearDown(harness.dispose);

    await harness.controller.start();
    harness.controller.updateText(0, '正文一句话');
    harness.controller.setDelivery(DeliveryMode.drift);

    final owned = await harness.controller.send();
    expect(owned, isNull);
    expect(harness.state.notice?.message, '服务器打了个盹');
    expect(harness.state.sending, isFalse);
    // 失败不清草稿：内容还在
    expect(harness.state.textCharCount, 5);
  });

  test('草稿防抖保存后，新会话能恢复文本/落款（投递方式不进草稿）', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.controller.start();
    harness.controller.updateText(0, '断网前写的半句话');
    harness.controller.setSignature('小海');
    harness.controller.setDelivery(DeliveryMode.drift);
    await harness.flushDraft();

    // 模拟杀进程重进：同一个草稿目录，全新的容器
    final container2 = ProviderContainer(
      overrides: [
        imageGatewayProvider.overrideWithValue(_FakeImageGateway([])),
        draftStoreProvider.overrideWithValue(
          DraftStore(baseDirFactory: () async => harness.tempDir),
        ),
      ],
    );
    addTearDown(container2.dispose);
    final subscription2 = container2.listen(writeControllerProvider, (_, _) {});
    addTearDown(subscription2.close);

    await container2.read(writeControllerProvider.notifier).start();
    final state = container2.read(writeControllerProvider);
    expect(state.restored, isTrue);
    expect(state.textCharCount, 8);
    expect(state.signature, '小海');
    expect(state.deliveryMode, isNull); // 模式不算手动内容，不进草稿
    expect(state.notice?.message, '已恢复上次的草稿');
  });

  test('照片草稿恢复后自动续传，已有 URL 的直接复用', () async {
    final harness = _Harness(
      images: [_png()],
      script: [
        ScriptedResponse.ok(201, {'url': 'https://t/u1.jpg'}),
      ],
    );
    addTearDown(harness.dispose);

    await harness.controller.start();
    harness.controller.updateText(0, 'x');
    await harness.controller.addPhotosAtCursor();
    await harness.flushDraft();
    expect(harness.state.photos.single.phase, PhotoUploadPhase.uploaded);

    // 新会话：不再提供上传脚本——已上传的照片直接复用 URL，不该再发请求
    final container2 = ProviderContainer(
      overrides: [
        imageGatewayProvider.overrideWithValue(_FakeImageGateway([])),
        draftStoreProvider.overrideWithValue(
          DraftStore(baseDirFactory: () async => harness.tempDir),
        ),
        apiClientProvider.overrideWithValue(
          ApiClient(
            dio: Dio(BaseOptions(baseUrl: 'http://test'))
              ..httpClientAdapter = ScriptedAdapter(const []),
            store: fakeSecureStore(),
          ),
        ),
      ],
    );
    addTearDown(container2.dispose);
    final subscription2 = container2.listen(writeControllerProvider, (_, _) {});
    addTearDown(subscription2.close);
    await container2.read(writeControllerProvider.notifier).start();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final photo = container2.read(writeControllerProvider).photos.single;
    expect(photo.remoteUrl, 'https://t/u1.jpg');
    expect(photo.phase, PhotoUploadPhase.uploaded);
  });

  test('移除夹在两段文字中间的照片：前后文本段自动合并，光标落缝点', () async {
    final harness = _Harness(
      images: [_png()],
      script: [
        ScriptedResponse.ok(201, {'url': 'https://t/u1.jpg'}),
      ],
    );
    addTearDown(harness.dispose);

    await harness.controller.start();
    harness.controller.updateText(0, '前半段和后半段');
    harness.controller.reportCursor(0, 3);
    await harness.controller.addPhotosAtCursor();
    await harness.settle();

    final state = harness.state;
    expect(state.blocks.length, 3);
    final photo = state.photos.single;

    await harness.controller.removePhoto(photo.id);
    await harness.settle();

    final after = harness.state;
    expect(after.photoCount, 0);
    expect(after.blocks.length, 1);
    expect((after.blocks.single as WriteTextBlock).text, '前半段\n和后半段');
    // 焦点（光标）请求落在换行之后＝新行行首
    expect(after.focusRequest?.blockId, after.blocks.single.id);
    expect(after.focusRequest?.offset, 4);
  });

  test('照片只有一侧是文字时不合并，两侧都空出来后照样缝合', () async {
    final harness = _Harness(
      images: [_png(), _png()],
      script: [
        ScriptedResponse.ok(201, {'url': 'https://t/u1.jpg'}),
        ScriptedResponse.ok(201, {'url': 'https://t/u2.jpg'}),
      ],
    );
    addTearDown(harness.dispose);

    await harness.controller.start();
    harness.controller.updateText(0, '前与后');
    harness.controller.reportCursor(0, 1);
    await harness.controller.addPhotosAtCursor();
    await harness.settle();

    // [前, 照1, 照2, 后]：移除照1 时另一侧是照片，不合并
    var blocks = harness.state.blocks;
    await harness.controller.removePhoto(blocks[1].id);
    await harness.settle();
    blocks = harness.state.blocks;
    expect(blocks.length, 3);
    expect((blocks[0] as WriteTextBlock).text, '前');
    expect(blocks[1], isA<WritePhotoBlock>());
    expect((blocks[2] as WriteTextBlock).text, '与后');

    // 再移除照2：两侧都是文字，缝合
    await harness.controller.removePhoto(blocks[1].id);
    await harness.settle();
    blocks = harness.state.blocks;
    expect(blocks.length, 1);
    expect((blocks.single as WriteTextBlock).text, '前\n与后');
  });

  test('进页静默补天气：全局定位现成就用，取不到就不显示', () async {
    final harness = _Harness(
      script: [
        ScriptedResponse.ok(200, {'text': '晴', 'temp_c': 27.5}),
      ],
    );
    addTearDown(harness.dispose);
    // 预置全局定位 ready：进页不该弹权限、直接拿现成坐标换天气
    harness.container
        .read(locationControllerProvider.notifier)
        .state = AppLocationState(
      phase: LocationPhase.ready,
      coordinate: GeoCoordinate(
        latitude: 30.27,
        longitude: 120.15,
        accuracyM: 10,
        measuredAt: DateTime.now(),
      ),
    );

    await harness.controller.start();
    await harness.settle();

    expect(harness.state.weather?.text, '晴');
  });

  test('定位没就绪时进页尝试静默定位，失败则天气留空不报错', () async {
    final harness = _Harness(script: const []);
    addTearDown(harness.dispose);

    await harness.controller.start();
    await harness.settle();

    // 单测环境没有定位插件：静默降级，weather 为空、无 notice
    expect(harness.state.weather, isNull);
    expect(harness.state.notice, isNull);
  });

  test('只选投递方式或只定地点：不算内容，不落草稿', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.controller.start();
    harness.controller.setDelivery(DeliveryMode.drift);
    await harness.flushDraft();
    expect(
      await harness.container.read(draftStoreProvider).loadJson('write'),
      isNull,
    );

    harness.controller.confirmDropPoint(lat: 30.27, lon: 120.15, label: '杭州');
    await harness.flushDraft();
    expect(
      await harness.container.read(draftStoreProvider).loadJson('write'),
      isNull,
    );
  });

  test('内容全部删光后草稿被清掉', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    await harness.controller.start();
    harness.controller.updateText(0, '半句话');
    harness.controller.setSignature('小海');
    await harness.flushDraft();
    expect(
      await harness.container.read(draftStoreProvider).loadJson('write'),
      isNotNull,
    );

    harness.controller.updateText(0, '');
    harness.controller.setSignature('');
    await harness.flushDraft();
    expect(
      await harness.container.read(draftStoreProvider).loadJson('write'),
      isNull,
    );
  });

  test('旧版草稿里的落点与投递方式被忽略，文本落款照常恢复', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    final store = harness.container.read(draftStoreProvider);
    await store.saveJson('write', {
      'version': DraftStore.draftVersion,
      'parent': null,
      'blocks': [
        {'kind': 'text', 'text': '旧草稿的半句话'},
      ],
      'signature': '小海',
      'addressee': '',
      'dropPoint': {'lat': 30.27, 'lon': 120.15, 'label': '浙江 · 杭州'},
      'deliveryMode': 'drift',
      'savedAt': '2026-08-01T10:00:00Z',
    });

    await harness.controller.start();
    final state = harness.state;
    expect(state.restored, isTrue);
    expect(state.textCharCount, 7);
    expect(state.signature, '小海');
    // 地点随定位走、模式不算内容：旧字段一律不带回来
    expect(state.dropPoint, isNull);
    expect(state.deliveryMode, isNull);
  });
}
