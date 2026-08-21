import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natsu_no_tegami/src/components/components.dart';
import 'package:natsu_no_tegami/src/tokens/natsu_tokens.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(fontFamily: 'NotoSansSC'),
      home: Scaffold(body: Center(child: child)),
    );

final ImageProvider _testImage = MemoryImage(Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    ]));

ImageProvider _resolve(String ref) => _testImage;

void main() {
  group('LetterBlock 序列化', () {
    test('TextBlock/PhotoBlock toJson/fromJson round-trip', () {
      final blocks = <LetterBlock>[
        const TextBlock('今天在海边坐了一下午。'),
        const PhotoBlock(
            imageRef: 'photo-a', mood: PhotoMood.overexposed, note: '潮風'),
        const TextBlock('回去的电车上，灯火像退潮一样流走。'),
      ];
      final restored = [for (final b in blocks) LetterBlock.fromJson(b.toJson())];
      expect(restored[0], isA<TextBlock>());
      expect((restored[0] as TextBlock).text, '今天在海边坐了一下午。');
      expect(restored[1], isA<PhotoBlock>());
      final photo = restored[1] as PhotoBlock;
      expect(photo.imageRef, 'photo-a');
      expect(photo.mood, PhotoMood.overexposed);
      expect(photo.note, '潮風');
    });

    test('省空字段：素 mood 与无手记的 PhotoBlock 序列化最小', () {
      const photo = PhotoBlock(imageRef: 'x');
      expect(photo.toJson(), {'type': 'photo', 'ref': 'x'});
    });

    test('fromJson 容忍缺失（旧信向前兼容）', () {
      final photo = PhotoBlock.fromJson({'type': 'photo', 'ref': 'x'});
      expect(photo.mood, PhotoMood.none);
      expect(photo.note, isNull);
    });

    test('未知 mood 名回落素（不崩旧数据）', () {
      expect(PhotoBlock.moodOf('vaporwave'), PhotoMood.none);
    });
  });

  group('validateLetterFlow', () {
    test('0–3 图合法', () {
      expect(
          validateLetterFlow([const TextBlock('a')]), isNull);
      expect(
          validateLetterFlow([
            const TextBlock('a'),
            const PhotoBlock(imageRef: '1'),
            const PhotoBlock(imageRef: '2'),
            const PhotoBlock(imageRef: '3'),
          ]),
          isNull);
    });

    test('4 图 = 叙事化违规句', () {
      final msg = validateLetterFlow([
        const TextBlock('a'),
        const PhotoBlock(imageRef: '1'),
        const PhotoBlock(imageRef: '2'),
        const PhotoBlock(imageRef: '3'),
        const PhotoBlock(imageRef: '4'),
      ]);
      expect(msg, isNotNull);
      expect(msg, contains('三张'));
    });

    test('空流 = 「信还没有写」', () {
      expect(validateLetterFlow(const []), contains('还没有写'));
    });
  });

  group('图文交替流渲染', () {
    testWidgets('文-图-文流：照片夹在两段正文之间（y 坐标居中）',
        (tester) async {
      await tester.pumpWidget(_wrap(LetterReading(
        blocks: const [
          TextBlock('第一段：今天在海边坐了一下午。'),
          PhotoBlock(imageRef: 'sea', note: '潮風'),
          TextBlock('第二段：回去的电车上。'),
        ],
        photoResolver: _resolve,
        place: '江の島',
        time: '2026.08.21',
      )));

      final textA = tester.getTopLeft(find.textContaining('第一段'));
      final photo = tester.getTopLeft(find.byType(PhotoCard));
      final textB = tester.getTopLeft(find.textContaining('第二段'));

      expect(textA.dy, lessThan(photo.dy), reason: '第一段在照片上方');
      expect(photo.dy, lessThan(textB.dy), reason: '照片在第二段上方');
    });

    testWidgets('署名渲染为横排（hwAddress）；无署名 findsNothing', (tester) async {
      await tester.pumpWidget(_wrap(LetterReading(
        blocks: const [TextBlock('正文')],
        photoResolver: _resolve,
        signature: '海辺にて',
      )));
      // 横排整词一个 Text + hwAddress 手写样式
      final sig = tester.widget<Text>(find.text('海辺にて'));
      expect(sig.style?.fontSize, NatsuTypography.hwAddress.fontSize);
      expect(sig.style?.fontFamily, NatsuTypography.hwAddress.fontFamily);
      // 定版：署名不再竖排（竖排只属于封筒宛名）
      expect(
        find.descendant(
            of: find.byType(LetterReading),
            matching: find.byType(VerticalHandwriting)),
        findsNothing,
      );

      await tester.pumpWidget(_wrap(LetterReading(
        blocks: const [TextBlock('正文')],
        photoResolver: _resolve,
      )));
      expect(find.text('海辺にて'), findsNothing);
    });

    testWidgets('photoResolver 由消费端解析 ref（解耦契约）', (tester) async {
      var resolvedRef = '';
      await tester.pumpWidget(_wrap(LetterReading(
        blocks: const [PhotoBlock(imageRef: 'asset://sea-01')],
        photoResolver: (ref) {
          resolvedRef = ref;
          return _testImage;
        },
      )));
      expect(resolvedRef, 'asset://sea-01');
      expect(find.byType(PhotoCard), findsOneWidget);
    });
  });

  group('照片 mood（PhotoCard）', () {
    testWidgets('素 = 无滤镜层（零回归）', (tester) async {
      await tester.pumpWidget(_wrap(PhotoCard(
        image: _testImage,
        seedId: 'mood-none',
        mood: PhotoMood.none,
      )));
      expect(find.byType(ColorFiltered), findsNothing);
      expect(find.byType(ImageFiltered), findsNothing);
    });

    testWidgets('过曝 = ColorFiltered + 颗粒共存（叠加不替代）', (tester) async {
      await tester.pumpWidget(_wrap(PhotoCard(
        image: _testImage,
        seedId: 'mood-ox',
        mood: PhotoMood.overexposed,
      )));
      expect(
        find.descendant(
            of: find.byType(PhotoCard), matching: find.byType(ColorFiltered)),
        findsOneWidget,
      );
      // 颗粒 painter（相纸介质）仍在 mood 之上
      expect(
        find.descendant(
            of: find.byType(PhotoCard), matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
    });

    testWidgets('逆光 = ColorFiltered；运动 = ImageFiltered', (tester) async {
      await tester.pumpWidget(_wrap(PhotoCard(
        image: _testImage,
        seedId: 'mood-bl',
        mood: PhotoMood.backlit,
      )));
      expect(find.byType(ColorFiltered), findsOneWidget);

      await tester.pumpWidget(_wrap(PhotoCard(
        image: _testImage,
        seedId: 'mood-mo',
        mood: PhotoMood.motion,
      )));
      expect(find.byType(ImageFiltered), findsOneWidget);
    });

    testWidgets('PhotoCard 默认 mood = 素（既有调用零回归）', (tester) async {
      await tester.pumpWidget(
          _wrap(PhotoCard(image: _testImage, seedId: 'legacy')));
      expect(find.byType(ColorFiltered), findsNothing);
      expect(find.byType(ImageFiltered), findsNothing);
    });
  });
}
