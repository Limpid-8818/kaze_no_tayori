import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/data/models/letter.dart';

void main() {
  test('LetterPublic 不含作者字段（匿名铁律在客户端的体现）', () {
    // 服务端不给作者字段，客户端就没有渲染它的可能。
    // 这里用 toJson 的键集合做守卫：加回 owner/author 会立刻变红。
    final letter = LetterPublic(
      id: 'x',
      blocks: const [LetterBlock(type: 'text', text: '海的彼岸')],
      themeId: 'natsu',
      themeSkin: null,
      deliveryMode: DeliveryMode.drift,
      counts: const LetterCounts(),
      createdAt: DateTime.utc(2026, 8, 20),
    );
    final keys = letter.toJson().keys.toSet();
    for (final banned in [
      'owner_user_id',
      'author',
      'author_id',
      'nickname',
      'avatar',
    ]) {
      expect(keys.contains(banned), isFalse, reason: '$banned 不该出现在信件模型里');
    }
    // 也不该有精确坐标
    expect(keys.contains('lat'), isFalse);
    expect(keys.contains('lon'), isFalse);
  });

  test('叙事计数只有 5 个', () {
    expect(const LetterCounts().toJson().keys.toSet(), {
      'read',
      'resonance',
      'voice',
      'reply',
      'saved',
    });
  });

  testWidgets('主题可构造并渲染', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KazeTheme.light(),
        home: const Scaffold(body: Text('风信')),
      ),
    );
    expect(find.text('风信'), findsOneWidget);
  });
}
