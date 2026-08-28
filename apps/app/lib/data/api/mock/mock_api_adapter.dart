/// 运行时 mock —— `--dart-define=USE_MOCK_API=true` 时接管全部网络。
///
/// 不起后端也能走通写信最小闭环（静默登录 → 选图上传 → 寄出）。
/// 只换 Dio 的 HttpClientAdapter，请求仍走真实 [ApiClient] 的解析与
/// 错误管线——mock 响应形状错了，会和真实后端一样在这里炸出来，
/// 契约不漂移。
///
/// 覆盖范围：写信流触达的端点 + 可降级模块（天气/逆地理）的罐头值。
/// 未覆盖的路径返回 404 错误体，提示补路由而不是静默成功。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class MockApiAdapter implements HttpClientAdapter {
  int _seq = 1;
  int _resonanceCount = 2;
  int _driftCursor = 0;

  /// 已共鸣的信——me_resonated 契约的 mock 侧（对齐服务端幂等语义）。
  final Set<String> _resonatedIds = {};

  /// 已拆封的信——发掘/漂流池不再回给同一台设备（对齐服务端语义）。
  final Set<String> _openedIds = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // 模拟真实网络节奏，让 loading 态可见
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final method = options.method.toUpperCase();
    final path = options.uri.path;

    if (method == 'POST' && path == '/v1/auth/device') {
      return _json(200, const {
        'access_token': 'mock.jwt.not-a-real-token',
        'token_type': 'bearer',
        'user_id': 'mock-user',
      });
    }
    if (method == 'POST' && path == '/v1/uploads/images') {
      return _json(201, {
        'url': 'https://mock.kaze.local/uploads/photo_$_seq.jpg',
      });
    }
    if (method == 'POST' &&
        (path == '/v1/letters' ||
            RegExp(r'^/v1/letters/[^/]+/replies$').hasMatch(path))) {
      return _json(201, _letterOwned(options));
    }
    // 随机漂流：按序吐两封种子信（其一含三行俳句），随后池空——
    // 「抽一封 → 换一封 → 叙事空态」整链路可在 mock 下验收。
    if (method == 'GET' && path == '/v1/drift/next') {
      final index = _driftCursor++;
      return index < _driftSeeds.length
          ? _json(200, _driftSeeds[index])
          : _json(404, const {
              'error': {
                'code': 'drift_pool_empty',
                'message': '此刻还没有漂来的信',
                'detail': null,
              },
            });
    }
    // 就地发掘：不校验坐标，回一封带诗 + 一封无诗；已拆封的不再出现
    if (method == 'GET' && path == '/v1/discover') {
      final items = [
        for (final letter in _staySeeds)
          if (!_openedIds.contains(letter['id'])) letter,
      ];
      return _json(200, {'items': items, 'next_cursor': null});
    }
    // 回信告知（F5）：一条未读 + 一条已读；unread_only 按 is_read 过滤
    if (method == 'GET' && path == '/v1/me/notifications') {
      // dio 的 queryParameters 保留原始类型：bool 就是 bool，不落字符串
      final unreadOnly =
          options.queryParameters['unread_only'].toString() == 'true';
      final items = [
        for (final n in _notifications)
          if (!unreadOnly || n['is_read'] == false) n,
      ];
      return _json(200, {'items': items, 'next_cursor': null});
    }
    final notifReadMatch = RegExp(r'^/v1/me/notifications/([^/]+)/read$')
        .firstMatch(path);
    if (method == 'POST' && notifReadMatch != null) {
      final id = notifReadMatch.group(1)!;
      for (var i = 0; i < _notifications.length; i++) {
        if (_notifications[i]['id'] == id) {
          _notifications[i] = {..._notifications[i], 'is_read': true};
        }
      }
      return _json(204, null);
    }
    // 读一封公开信：种子信可读，其余 404（读信空态可测）
    final letterMatch = RegExp(r'^/v1/letters/([^/]+)$').firstMatch(path);
    if (method == 'GET' && letterMatch != null) {
      final json = _publicLetterById(letterMatch.group(1)!);
      return json != null
          ? _json(200, {
              ...json,
              'me_resonated': _resonatedIds.contains(letterMatch.group(1)),
            })
          : _json(404, const {
              'error': {
                'code': 'letter_not_found',
                'message': '信不存在或尚未漂到公开水域',
                'detail': null,
              },
            });
    }
    if (method == 'POST' &&
        RegExp(r'^/v1/letters/[^/]+/read$').hasMatch(path)) {
      final readMatch = RegExp(r'^/v1/letters/([^/]+)/read$').firstMatch(path);
      if (readMatch != null) _openedIds.add(readMatch.group(1)!);
      return _json(204, null);
    }
    if (method == 'POST' &&
        RegExp(r'^/v1/letters/[^/]+/report$').hasMatch(path)) {
      return _json(204, null);
    }
    if (method == 'POST' &&
        RegExp(r'^/v1/letters/[^/]+/resonance$').hasMatch(path)) {
      // 幂等：重复共鸣计数不再涨，但 me_resonated 依然为真
      final id = RegExp(r'^/v1/letters/([^/]+)/resonance$')
          .firstMatch(path)!
          .group(1)!;
      if (_resonatedIds.add(id)) _resonanceCount++;
      return _json(201, {'resonance_count': _resonanceCount});
    }
    if (method == 'GET' && path == '/v1/weather/now') {
      return _json(200, const {'text': '晴', 'temp_c': 27.5, 'icon': 'clear'});
    }
    if (method == 'GET' && path == '/v1/geo/reverse') {
      return _json(200, const {'place_label': '浙江 · 杭州'});
    }
    // 我的信（F6）：四种状态各一封，徽标/长按下架链路可离线验收
    if (method == 'GET' && path == '/v1/me/letters') {
      return _json(200, {'items': _ownedSeeds, 'next_cursor': null});
    }
    final ownedMatch = RegExp(r'^/v1/me/letters/([^/]+)$').firstMatch(path);
    if (method == 'DELETE' && ownedMatch != null) {
      final id = ownedMatch.group(1)!;
      final index = _ownedSeeds.indexWhere((json) => json['id'] == id);
      // 服务端语义：非本人或不存在一律 not_found；命中则置 taken_down 非硬删
      if (index < 0) {
        return _json(404, const {
          'error': {
            'code': 'not_found',
            'message': '信不存在或你没有权限操作此信',
            'detail': null,
          },
        });
      }
      _ownedSeeds[index] = {..._ownedSeeds[index], 'status': 'taken_down'};
      return _json(204, null);
    }
    // 抄本（F7）：初始两封收藏（带诗 + 无诗），收进幂等去重、移出不
    // 存在回 404——对齐服务端语义，收藏/移出整链路可离线验收。
    if (method == 'GET' && path == '/v1/me/scripbook') {
      return _json(200, {'items': _scripbookSeeds, 'next_cursor': null});
    }
    if (method == 'POST' && path == '/v1/me/scripbook') {
      final body = options.data is Map<String, dynamic>
          ? options.data as Map<String, dynamic>
          : const <String, dynamic>{};
      final letterId = body['letter_id'] as String?;
      final letter = letterId == null ? null : _publicLetterById(letterId);
      if (letter == null) {
        return _json(404, const {
          'error': {
            'code': 'letter_not_found',
            'message': '信不存在或尚未漂到公开水域',
            'detail': null,
          },
        });
      }
      if (!_scripbookSeeds.any((json) => json['id'] == letterId)) {
        _scripbookSeeds.insert(0, {...letter});
      }
      return _json(204, null);
    }
    final scripMatch = RegExp(r'^/v1/me/scripbook/([^/]+)$').firstMatch(path);
    if (method == 'DELETE' && scripMatch != null) {
      final id = scripMatch.group(1)!;
      final index = _scripbookSeeds.indexWhere((json) => json['id'] == id);
      if (index < 0) {
        return _json(404, const {
          'error': {'code': 'not_found', 'message': '抄本中没有这封信', 'detail': null},
        });
      }
      _scripbookSeeds.removeAt(index);
      return _json(204, null);
    }
    if (method == 'GET' && path == '/health') {
      return _json(200, const {'status': 'ok'});
    }
    return _json(404, {
      'error': {
        'code': 'not_found',
        'message': 'mock 未覆盖的路由: $method $path',
        'detail': null,
      },
    });
  }

  /// 回显请求体组装 LetterOwned —— 寄出什么就「落库」什么，方便核对。
  Map<String, Object?> _letterOwned(RequestOptions options) {
    final body = options.data is Map<String, dynamic>
        ? options.data as Map<String, dynamic>
        : const <String, dynamic>{};
    return {
      'id': 'mock_letter_${_seq++}',
      'blocks': body['blocks'] ?? const <Object>[],
      'poem': null,
      'signature': body['signature'],
      'addressee': body['addressee'],
      'theme_id': body['theme_id'] ?? 'natsu',
      'theme_skin': null,
      'music_ref': null,
      'place_label': body['place_label'],
      'weather': body['weather'],
      'tags': const <String>[],
      'delivery_mode': body['delivery_mode'] ?? 'drift',
      'parent_letter_id': null,
      'counts': const {
        'read': 0,
        'resonance': 0,
        'voice': 0,
        'reply': 0,
        'saved': 0,
      },
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
      'lat': body['lat'],
      'lon': body['lon'],
    };
  }

  /// 固定种子信（mock_letter_1）——含文本/照片交替流，读信页 mock 数据源。
  Map<String, Object?> _letterPublic() {
    return {
      'id': 'mock_letter_1',
      'blocks': const [
        {'type': 'text', 'text': '傍晚的海边风很大，把想说的话都吹散了。'},
        {
          'type': 'photo',
          'ref': 'https://mock.kaze.local/uploads/photo_seed.jpg',
          'mood': 'backlit',
          'note': '逆光的防波堤',
        },
        {'type': 'text', 'text': '就把它们写进信里，交给风。'},
      ],
      'poem': null,
      'signature': '赶海的人',
      'addressee': null,
      'theme_id': 'natsu',
      'theme_skin': null,
      'music_ref': null,
      'place_label': '浙江 · 舟山',
      'weather': const {'text': '多云', 'temp_c': 26.0, 'icon': 'cloudy'},
      'tags': const <String>[],
      'delivery_mode': 'drift',
      'parent_letter_id': null,
      'counts': {
        'read': 3,
        'resonance': _resonanceCount,
        'voice': 0,
        'reply': 0,
        'saved': 0,
      },
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  // ---------- 收信双入口的种子信（F4） ----------

  /// 组一封 LetterPublic 形状的公开信。时间以 now 往前回退，
  /// 让列表卡能呈现「N 小时前 / N 天前」。
  Map<String, Object?> _seedLetter({
    required String id,
    required List<Object?> blocks,
    required String deliveryMode,
    Duration ago = const Duration(hours: 2),
    Object? poem,
    String? addressee,
    Map<String, Object?>? skin,
    required String placeLabel,
    required Map<String, Object?> weather,
    String signature = '不具名',
    String? parentLetterId,
  }) {
    return {
      'id': id,
      'blocks': blocks,
      'poem': poem,
      'signature': signature,
      'addressee': addressee,
      'theme_id': 'natsu',
      'theme_skin': skin,
      'music_ref': null,
      'place_label': placeLabel,
      'weather': weather,
      'tags': const <String>[],
      'delivery_mode': deliveryMode,
      'parent_letter_id': parentLetterId,
      'counts': const {
        'read': 0,
        'resonance': 1,
        'voice': 0,
        'reply': 0,
        'saved': 0,
      },
      'created_at': DateTime.now().subtract(ago).toIso8601String(),
    };
  }

  /// 漂流池：第一封带宛名+俳句（封面竖排字与阅读器短诗可验），
  /// 第二封带皮肤+纯文本。抽完即 drift_pool_empty。
  List<Map<String, Object?>> get _driftSeeds => [
    _seedLetter(
      id: 'mock_drift_1',
      deliveryMode: 'drift',
      addressee: '拾到它的人',
      poem: '风穿过堤岸\n把下午吹得很轻\n浪只说了一半',
      placeLabel: '浙江 · 舟山',
      weather: const {'text': '多云', 'temp_c': 26.0, 'icon': 'cloudy'},
      blocks: const [
        {'type': 'text', 'text': '傍晚的海边风很大，把想说的话都吹散了。'},
        {'type': 'text', 'text': '就把它们写进信里，交给风。'},
      ],
    ),
    _seedLetter(
      id: 'mock_drift_2',
      deliveryMode: 'drift',
      ago: const Duration(days: 3),
      skin: const {
        'stamp': 'stamp.sea-01',
        'postmarkEmblem': 'postmark.cicada-01',
      },
      placeLabel: '福建 · 厦门',
      weather: const {'text': '晴', 'temp_c': 31.0, 'icon': 'clear'},
      blocks: const [
        {'type': 'text', 'text': '风从骑楼的廊柱间穿过的时候，整条老街都在轻轻摇晃。'},
        {'type': 'text', 'text': '如果你在第七个路口闻到桂花，就当是我打过招呼。'},
      ],
      signature: '八市买鱼的人',
    ),
  ];

  /// 发掘结果：一封带诗 + 一封无诗（无诗走两行手写预览位）。
  List<Map<String, Object?>> get _staySeeds => [
    _seedLetter(
      id: 'mock_stay_1',
      deliveryMode: 'stay',
      poem: '梧桐叶的缝隙\n漏下来的光斑\n替我读完了信',
      placeLabel: '浙江 · 杭州',
      signature: '西湖边写生的人',
      weather: const {'text': '晴', 'temp_c': 29.0, 'icon': 'clear'},
      blocks: const [
        {'type': 'text', 'text': '把这张便条压在长椅底下的人说，坐下来歇脚的你辛苦了。'},
      ],
    ),
    _seedLetter(
      id: 'mock_stay_2',
      deliveryMode: 'stay',
      ago: const Duration(minutes: 40),
      placeLabel: '上海 · 武康路',
      weather: const {'text': '多云', 'temp_c': 28.0, 'icon': 'cloudy'},
      blocks: const [
        {'type': 'text', 'text': '风从梧桐树叶间穿过的时候，整条街都在轻轻摇晃。'},
        {'type': 'text', 'text': '陪你走路的那个人先别急着道别。'},
      ],
      signature: '街角咖啡师',
    ),
  ];

  /// 回信种子（F5）：都是 mock_stay_1 收到的独立回信作品，
  /// 告知条目点开能进真实阅读器读到完整信纸。
  List<Map<String, Object?>> get _replySeeds => [
    _seedLetter(
      id: 'mock_reply_2',
      deliveryMode: 'drift',
      ago: const Duration(hours: 3),
      parentLetterId: 'mock_stay_1',
      poem: '风把长椅吹干净\n你留下的那句话\n被下一个人捡到了',
      placeLabel: '浙江 · 杭州',
      signature: '坐在长椅另一头的人',
      weather: const {'text': '晴', 'temp_c': 30.0, 'icon': 'clear'},
      blocks: const [
        {'type': 'text', 'text': '也在那张长椅上坐了一个下午，替你把便条读了两遍。'},
        {'type': 'text', 'text': '换我留半句话给风：别急着和这座城市道别。'},
      ],
    ),
    _seedLetter(
      id: 'mock_reply_1',
      deliveryMode: 'drift',
      ago: const Duration(days: 1),
      parentLetterId: 'mock_stay_1',
      placeLabel: '江苏 · 南京',
      signature: '路过的人',
      weather: const {'text': '多云', 'temp_c': 27.0, 'icon': 'cloudy'},
      blocks: const [
        {'type': 'text', 'text': '歇脚的时候读到你的字。辛苦是会过去的，风都知道。'},
      ],
    ),
  ];

  /// 我的信种子（F6）：四种 LetterStatus 各占一封，覆盖徽标全形态与
  /// 「长按 → 两段确认 → 下架」离线链路。公开的那封可从列表点进阅读器；
  /// 下架会把它翻成 taken_down（非硬删，仍在列表）。
  late final List<Map<String, Object?>> _ownedSeeds = [
    _ownedSeed(
      id: 'mock_mine_1',
      status: 'public',
      ago: const Duration(hours: 2),
      poem: '候鸟排成人字\n把我的问候带走\n往更南的南方',
      placeLabel: '浙江 · 舟山',
      weather: const {'text': '晴', 'temp_c': 29.0, 'icon': 'clear'},
      blocks: const [
        {'type': 'text', 'text': '在海堤上写完这封，浪来过两次，纸角湿了一点。'},
        {'type': 'text', 'text': '希望捡到它的人，今天也恰好有风。'},
      ],
      signature: '赶海的人',
    ),
    _ownedSeed(
      id: 'mock_mine_2',
      status: 'pending',
      ago: const Duration(minutes: 40),
      placeLabel: '浙江 · 杭州',
      weather: const {'text': '多云', 'temp_c': 28.0, 'icon': 'cloudy'},
      blocks: const [
        {'type': 'text', 'text': '刚写下的一封还在路上：先交给审核，再交给风。'},
      ],
    ),
    _ownedSeed(
      id: 'mock_mine_3',
      status: 'rejected',
      ago: const Duration(days: 2),
      placeLabel: '上海 · 武康路',
      weather: const {'text': '阴', 'temp_c': 24.0, 'icon': 'cloudy'},
      blocks: const [
        {'type': 'text', 'text': '这一封没能通过审核——只有你自己看得见它。'},
      ],
    ),
    _ownedSeed(
      id: 'mock_mine_4',
      status: 'taken_down',
      ago: const Duration(days: 5),
      placeLabel: '江苏 · 南京',
      weather: const {'text': '多云', 'temp_c': 27.0, 'icon': 'cloudy'},
      blocks: const [
        {'type': 'text', 'text': '这一封已经被收回来了，但写给它的回信都还在。'},
      ],
    ),
  ];

  /// 组一封 LetterOwned 形状的本人信（在 [_seedLetter] 上补状态与落点坐标）。
  Map<String, Object?> _ownedSeed({
    required String id,
    required String status,
    required List<Object?> blocks,
    double lat = 30.0,
    double lon = 121.0,
    Duration ago = const Duration(hours: 2),
    Object? poem,
    String? addressee,
    Map<String, Object?>? skin,
    required String placeLabel,
    required Map<String, Object?> weather,
    String signature = '不具名',
    String? parentLetterId,
  }) {
    return {
      ..._seedLetter(
        id: id,
        blocks: blocks,
        deliveryMode: 'drift',
        ago: ago,
        poem: poem,
        addressee: addressee,
        skin: skin,
        placeLabel: placeLabel,
        weather: weather,
        signature: signature,
        parentLetterId: parentLetterId,
      ),
      'status': status,
      'lat': lat,
      'lon': lon,
    };
  }

  /// 抄本种子（F7）：带诗 + 无诗各一封的拷贝，覆盖摘要卡两种形态。
  /// 收进/移出直接增删这份内存列表——与服务端一样幂等、可反复横跳；
  /// 最新收进的排最前（added_at DESC）。
  late final List<Map<String, Object?>> _scripbookSeeds = [
    {..._driftSeeds.first},
    {..._staySeeds.first},
  ];

  /// 回信告知种子（F5）：最新在前；两条各指向一封可读的种子回信。
  late final List<Map<String, Object?>> _notifications = [
    _notification(
      id: 'mock_notif_2',
      letterId: 'mock_reply_2',
      parentId: 'mock_stay_1',
      placeLabel: '浙江 · 杭州',
      ago: const Duration(hours: 3),
    ),
    _notification(
      id: 'mock_notif_1',
      letterId: 'mock_reply_1',
      parentId: 'mock_stay_1',
      placeLabel: '浙江 · 杭州',
      isRead: true,
      ago: const Duration(days: 1),
    ),
  ];

  Map<String, Object?> _notification({
    required String id,
    required String letterId,
    required String parentId,
    required String placeLabel,
    Duration ago = const Duration(hours: 1),
    bool isRead = false,
  }) {
    return {
      'id': id,
      'type': 'reply',
      'letter_id': letterId,
      'parent_letter_id': parentId,
      'parent_place_label': placeLabel,
      'is_read': isRead,
      'created_at': DateTime.now().subtract(ago).toIso8601String(),
    };
  }

  /// 详情白名单：mock_letter_1 行为不变（共鸣计数联动），其余种子信
  /// 静态回放——保证从漂流/发掘/告知点开能进真实 F3 阅读器。
  /// 本人公开种子（F6）也在此列，但只在 public 时可读：下架后读者侧
  /// 与服务端一样回 404，「我的信」点开即见阅读器的叙事空态。
  Map<String, Object?>? _publicLetterById(String id) {
    if (id == 'mock_letter_1') return _letterPublic();
    final owned = _ownedSeeds.where((json) => json['id'] == id).toList();
    if (owned.isNotEmpty) {
      return owned.single['status'] == 'public' ? owned.single : null;
    }
    return [..._driftSeeds, ..._staySeeds, ..._replySeeds]
        .cast<Map<String, Object?>?>()
        .firstWhere((json) => json!['id'] == id, orElse: () => null);
  }

  ResponseBody _json(int status, Object? data) {
    final encoded = utf8.encode(jsonEncode(data));
    return ResponseBody(
      Stream<Uint8List>.fromIterable([Uint8List.fromList(encoded)]),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
