/// 天色桥接层测试 —— icon 归类、时段边界、12 档查表与 debug 解析。
library;

import 'package:flutter/painting.dart' show LinearGradient;
import 'package:flutter_test/flutter_test.dart';

import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/core/day_period.dart';

void main() {
  group('KazeSky.fromIcon', () {
    test('后端三档归类直映', () {
      expect(KazeSky.fromIcon('sunny'), KazeWeather.sunny);
      expect(KazeSky.fromIcon('cloudy'), KazeWeather.cloudy);
      expect(KazeSky.fromIcon('rainy'), KazeWeather.rainy);
    });

    test('mock 的 clear、null 与未知值兜底按晴（宁亮勿暗）', () {
      expect(KazeSky.fromIcon('clear'), KazeWeather.sunny);
      expect(KazeSky.fromIcon(null), KazeWeather.sunny);
      expect(KazeSky.fromIcon('snowy'), KazeWeather.sunny);
      expect(KazeSky.fromIcon(''), KazeWeather.sunny);
    });
  });

  group('KazeSky.daypartOf', () {
    DateTime at(int hour, [int minute = 0]) =>
        DateTime(2026, 8, 27, hour, minute);

    test('边界沿用 core/day_period：朝 5–11 / 昼 11–17 / 夕 17–22 / 其余夜', () {
      expect(
        KazeSky.daypartOf(at(4, 59)),
        KazeDaypart.night,
        reason: '04:59 属夜',
      );
      expect(KazeSky.daypartOf(at(5)), KazeDaypart.morning);
      expect(KazeSky.daypartOf(at(10, 59)), KazeDaypart.morning);
      expect(KazeSky.daypartOf(at(11)), KazeDaypart.noon);
      expect(KazeSky.daypartOf(at(16, 59)), KazeDaypart.noon);
      expect(KazeSky.daypartOf(at(17)), KazeDaypart.dusk);
      expect(KazeSky.daypartOf(at(21, 59)), KazeDaypart.dusk);
      expect(KazeSky.daypartOf(at(22)), KazeDaypart.night);
    });

    test('映射口径：core 的 evening 即库内的 dusk', () {
      expect(dayPeriodOf(at(18)), KazeDayPeriod.evening);
      expect(KazeSky.daypartOf(at(18)), KazeDaypart.dusk);
    });
  });

  group('KazeSky.of / defaultGradient', () {
    test('12 组合全部命中且互异', () {
      final gradients = <LinearGradient>{
        for (final w in KazeWeather.values)
          for (final t in KazeDaypart.values) KazeSky.of(w, t),
      };
      expect(gradients.length, 12);
    });

    test('昼·晴就是默认天空（回归基准）', () {
      expect(
        identical(
          KazeSky.defaultGradient,
          KazeSky.of(KazeWeather.sunny, KazeDaypart.noon),
        ),
        isTrue,
      );
    });
  });

  group('KazeSky.parseForce', () {
    test('12 键 camelCase 全部可解析', () {
      expect(KazeSky.parseForce('morningSunny'), (
        KazeWeather.sunny,
        KazeDaypart.morning,
      ));
      expect(KazeSky.parseForce('noonSunny'), (
        KazeWeather.sunny,
        KazeDaypart.noon,
      ));
      expect(KazeSky.parseForce('duskSunny'), (
        KazeWeather.sunny,
        KazeDaypart.dusk,
      ));
      expect(KazeSky.parseForce('nightSunny'), (
        KazeWeather.sunny,
        KazeDaypart.night,
      ));
      expect(KazeSky.parseForce('duskCloudy'), (
        KazeWeather.cloudy,
        KazeDaypart.dusk,
      ));
      expect(KazeSky.parseForce('nightRainy'), (
        KazeWeather.rainy,
        KazeDaypart.night,
      ));

      // 全矩阵穷举
      for (final w in KazeWeather.values) {
        final capW = '${w.name[0].toUpperCase()}${w.name.substring(1)}';
        for (final t in KazeDaypart.values) {
          expect(KazeSky.parseForce('${t.name}$capW'), (w, t));
        }
      }
    });

    test('非法值返回 null（忽略覆盖）', () {
      expect(KazeSky.parseForce(''), isNull);
      expect(KazeSky.parseForce('night'), isNull);
      expect(KazeSky.parseForce('nightRains'), isNull);
      expect(KazeSky.parseForce('NIGHT_RAINY'), isNull);
      expect(KazeSky.parseForce('morningSnowy'), isNull);
    });
  });
}
