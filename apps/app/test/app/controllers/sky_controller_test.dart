/// 全局天色控制器测试 —— 合成优先级、依赖流入与相等短路。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kazenotayori/app/controllers/home_environment_controller.dart';
import 'package:kazenotayori/app/controllers/sky_controller.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/data/models/letter.dart';
import 'package:kazenotayori/features/settings/settings_store.dart';

/// 等待微任务清空（SkyController 的 listen 经 Future.microtask 挂载）。
Future<void> _pumpMicrotasks() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.microtask(() {});
  }
}

void main() {
  group('SkyController', () {
    test('初始：无天气信息时按「当前时段·晴」渲染', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sky = container.read(skyControllerProvider);
      expect(sky.weather, KazeWeather.sunny); // 天气未达 = 晴兜底
      // 时段可从本地时钟恒推导；不锁死具体档位（时钟属环境）
      expect(sky.daypart, isNotNull);
    });

    test('clock 可注入：正午固定时刻 → 昼·晴', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(skyControllerProvider.notifier);
      notifier.clock = () => DateTime(2026, 8, 27, 13);
      notifier.refresh();

      final sky = container.read(skyControllerProvider);
      expect(sky.weather, KazeWeather.sunny);
      expect(sky.daypart, KazeDaypart.noon);
    });

    test('时段跨越经 refresh 追认：昼 → 夕', () {
      var now = DateTime(2026, 8, 27, 15);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(skyControllerProvider.notifier);
      notifier.clock = () => now;
      notifier.refresh();
      expect(container.read(skyControllerProvider).daypart, KazeDaypart.noon);

      now = DateTime(2026, 8, 27, 18);
      notifier.refresh();
      expect(container.read(skyControllerProvider).daypart, KazeDaypart.dusk);
    });

    test('天气流入自动换天气档', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(skyControllerProvider.notifier);
      notifier.clock = () => DateTime(2026, 8, 27, 13);
      notifier.refresh();

      container
          .read(homeEnvironmentControllerProvider.notifier)
          .state = const HomeEnvironmentState(
        weather: Weather(text: '小雨', icon: 'rainy'),
      );
      await _pumpMicrotasks(); // listen 已挂载并响应

      final sky = container.read(skyControllerProvider);
      expect(sky.weather, KazeWeather.rainy);
      expect(sky.daypart, KazeDaypart.noon);
    });

    test('关闭自动联动 → 全局固定昼·晴', () async {
      var now = DateTime(2026, 8, 27, 23); // 深夜
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(skyControllerProvider.notifier);
      notifier.clock = () => now;
      notifier.refresh();

      await container.read(settingsProvider.notifier).setSkyAutoEnabled(false);
      await _pumpMicrotasks();

      final sky = container.read(skyControllerProvider);
      expect(
        sky,
        const SkyState(weather: KazeWeather.sunny, daypart: KazeDaypart.noon),
      );

      // 时段继续走也不会再跟着变
      now = DateTime(2026, 8, 28, 9);
      container.read(skyControllerProvider.notifier).refresh();
      expect(
        container.read(skyControllerProvider),
        const SkyState(weather: KazeWeather.sunny, daypart: KazeDaypart.noon),
      );

      // 重新开启 → 回到自动档（当前时段·晴）
      await container.read(settingsProvider.notifier).setSkyAutoEnabled(true);
      await _pumpMicrotasks();
      expect(
        container.read(skyControllerProvider).daypart,
        KazeDaypart.morning,
        reason: '09:00 属朝',
      );
    });
  });
}
