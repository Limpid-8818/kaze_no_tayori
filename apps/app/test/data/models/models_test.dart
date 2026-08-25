import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/data/models/catalog.dart';
import 'package:kazenotayori/data/models/common.dart';
import 'package:kazenotayori/data/models/notification.dart';

void main() {
  group('Page', () {
    test('解析 items + next_cursor', () {
      final page = Page.fromJson({
        'items': [
          {'id': 'n-1'},
          {'id': 'n-2'},
        ],
        'next_cursor': null,
      }, (json) => json['id'] as String);
      expect(page.items, ['n-1', 'n-2']);
      expect(page.nextCursor, isNull);
    });

    test('items 缺失或含坏项时显式失败，不能伪装空状态', () {
      expect(
        () => Page.fromJson({}, (json) => ''),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Page.fromJson({
          'items': ['bad'],
        }, (json) => ''),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('TokenResponse', () {
    test('snake_case 映射', () {
      final t = TokenResponse.fromJson({
        'access_token': 'jwt',
        'token_type': 'bearer',
        'user_id': 'u-1',
      });
      expect(t.accessToken, 'jwt');
      expect(t.tokenType, 'bearer');
      expect(t.userId, 'u-1');
    });
  });

  group('NotificationPublic', () {
    test('完整字段解析', () {
      final n = NotificationPublic.fromJson({
        'id': 'n-1',
        'type': 'reply',
        'letter_id': 'l-2',
        'parent_letter_id': 'l-1',
        'parent_place_label': 'Tokyo',
        'is_read': true,
        'created_at': '2026-08-20T23:47:00+09:00',
      });
      expect(n.type, NotificationType.reply);
      expect(n.letterId, 'l-2');
      expect(n.parentLetterId, 'l-1');
      expect(n.isRead, isTrue);
    });
  });

  group('Catalog', () {
    test('ThemePublic 含 assets 与 is_default', () {
      final t = ThemePublic.fromJson({
        'id': 'natsu',
        'name': '夏の手紙',
        'assets': {
          'stamp': ['s-1'],
        },
        'is_default': true,
      });
      expect(t.isDefault, isTrue);
      expect(t.assets['stamp'], isA<List>());
    });

    test('TagPublic', () {
      final tag = TagPublic.fromJson({
        'id': 'journey',
        'name': '旅途',
        'color': '#FF6B6B',
      });
      expect(tag.name, '旅途');
    });
  });

  group('请求体 toJson', () {
    test('ScripbookAddRequest letter_id snake_case', () {
      final json = const ScripbookAddRequest(letterId: 'l-1').toJson();
      expect(json['letter_id'], 'l-1');
    });

    test('ReportRequest', () {
      final json = const ReportRequest(reason: '垃圾广告').toJson();
      expect(json['reason'], '垃圾广告');
    });

    test('ResonanceRequest 空 note 也合法', () {
      final json = const ResonanceRequest().toJson();
      expect(json['note'], isNull);
    });

    test('ResonanceResponse resonance_count 映射', () {
      final r = ResonanceResponse.fromJson({'resonance_count': 3});
      expect(r.resonanceCount, 3);
    });
  });
}
