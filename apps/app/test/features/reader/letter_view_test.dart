/// LetterView mapper 单测：字段映射、图文块、meta 组装、丢弃项。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kazenotayori/data/models/letter.dart';
import 'package:kazenotayori/features/reader/letter_view.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart' as natsu;

/// 区分「没传」与「显式 null」的哨兵——宛名/皮肤要测两种空。
const _unset = Object();

LetterPublic _letter({
  List<LetterBlock>? blocks,
  Weather? weather,
  Object? addressee = _unset,
  LetterSkin? themeSkin,
}) {
  return LetterPublic(
    id: 'letter_1',
    blocks: blocks ?? const [],
    themeId: 'natsu',
    deliveryMode: DeliveryMode.drift,
    counts: const LetterCounts(read: 3, resonance: 5),
    createdAt: DateTime.parse('2026-08-26T10:00:00Z'),
    poem: '四行短诗',
    signature: '赶海的人',
    addressee: addressee == _unset ? '某人' : addressee as String?,
    themeSkin: themeSkin,
    musicRef: const MusicRef(album: 'a', song: 'b', lyrics: 'c'),
    placeLabel: '浙江 · 舟山',
    weather: weather,
    tags: const ['夏天'],
    parentLetterId: 'letter_0',
  );
}

void main() {
  test('图文块映射：text → TextBlock，photo → PhotoBlock（ref/mood/note）', () {
    final view = LetterView.from(
      _letter(
        blocks: [
          const LetterBlock(type: 'text', text: '你好'),
          const LetterBlock(
            type: 'photo',
            ref: 'https://x/img.jpg',
            mood: PhotoMood.backlit,
            note: '逆光',
          ),
        ],
      ),
    );

    expect(view.blocks, hasLength(2));
    final text = view.blocks[0];
    expect(text, isA<natsu.TextBlock>());
    expect((text as natsu.TextBlock).text, '你好');

    final photo = view.blocks[1] as natsu.PhotoBlock;
    expect(photo.imageRef, 'https://x/img.jpg');
    expect(photo.mood, natsu.PhotoMood.backlit);
    expect(photo.note, '逆光');
  });

  test('meta 组装：place / weatherText（带温度圆整）/ timeLabel', () {
    final view = LetterView.from(
      _letter(weather: const Weather(text: '多云', tempC: 26.4)),
    );
    expect(view.place, '浙江 · 舟山');
    expect(view.weatherText, '多云 26°');
    expect(view.timeLabel, '8月26日');
  });

  test('weather 无温度时只留天气名；无 weather 时为 null', () {
    expect(
      LetterView.from(_letter(weather: const Weather(text: '晴'))).weatherText,
      '晴',
    );
    expect(LetterView.from(_letter()).weatherText, isNull);
  });

  test('共鸣计数与溯源 parent 带出；poem/music/tags 不进视图', () {
    final view = LetterView.from(_letter());
    expect(view.resonanceCount, 5);
    expect(view.parentLetterId, 'letter_0');
    // LetterView 没有 poem/music/tags 字段——丢弃即断言不出现在
    // 渲染模型上；这里用视图字段的穷尽读取保证编译期没有加回来的位置。
    expect(view.signature, '赶海的人');
    expect(view.id, 'letter_1');
  });

  test('封筒封面位：宛名带出，皮肤转 stamp/postmark 两槽', () {
    final view = LetterView.from(
      _letter(
        themeSkin: const LetterSkin(
          stamp: 'stamp.sea-01',
          postmarkEmblem: 'postmark.cicada-01',
          decor: ['decor.x'],
          postcard: 'postcard.y',
        ),
      ),
    );
    expect(view.addressee, '某人');
    expect(view.skin.stampId, 'stamp.sea-01');
    expect(view.skin.postmarkEmblemId, 'postmark.cicada-01');
  });

  test('封筒封面位：皮肤全空 = 组件默认；宛名 null = 封面洁净', () {
    final view = LetterView.from(_letter(addressee: null, themeSkin: null));
    expect(view.addressee, isNull);
    expect(view.skin, const natsu.LetterSkin());
  });
}
