/// 动画天空容器测试 —— 档位切换的渐变插值与读信页覆盖。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kazenotayori/app/controllers/sky_controller.dart';
import 'package:kazenotayori/app/theme.dart';
import 'package:kazenotayori/app/widgets/kaze_sky_box.dart';

/// 可测试中手动换挡的天色替身。
class _FixedSkyController extends SkyController {
  _FixedSkyController(this._state);

  SkyState _state;

  @override
  SkyState build() => _state;

  void force(SkyState next) {
    _state = next;
    state = next;
  }
}

const _nightRainy = SkyState(
  weather: KazeWeather.rainy,
  daypart: KazeDaypart.night,
);
const _noonSunny = SkyState(
  weather: KazeWeather.sunny,
  daypart: KazeDaypart.noon,
);

/// 当前渲染中的渐变 —— AnimatedContainer 内层 Container 的 decoration
/// 才是插值实时值（widget 自身的 decoration 恒为目标值）。
BoxDecoration _decoOf(WidgetTester tester) =>
    tester.widget<Container>(find.byType(Container)).decoration!
        as BoxDecoration;

void main() {
  testWidgets('跟随全局天色：换挡后 drift 插值到目标渐变', (tester) async {
    final controller = _FixedSkyController(_nightRainy);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [skyControllerProvider.overrideWith(() => controller)],
        child: const MaterialApp(home: KazeSkyBox(child: SizedBox.expand())),
      ),
    );

    // 初帧即注入档位（渐变端点是同一 const 值）
    expect(
      (_decoOf(tester).gradient! as LinearGradient).colors.first,
      KazeSky.of(KazeWeather.rainy, KazeDaypart.night).colors.first,
    );

    // 夜·雨 → 昼·晴：中途颜色在两档之间（证明 lerp 真的发生）
    final startTop = (_decoOf(tester).gradient! as LinearGradient).colors.first;
    controller.force(_noonSunny);
    await tester.pump(); // 帧一：rebuild + 动画启动（t=0）
    await tester.pump(KazeMotion.drift * 0.5); // 帧二：推进半程
    final midTop = (_decoOf(tester).gradient! as LinearGradient).colors.first;
    expect(midTop, isNot(startTop));
    expect(
      midTop,
      isNot(KazeSky.of(_noonSunny.weather, _noonSunny.daypart).colors.first),
    );

    await tester.pumpAndSettle();
    expect(
      (_decoOf(tester).gradient! as LinearGradient).colors.first,
      KazeSky.defaultGradient.colors.first,
    );
  });

  testWidgets('传入覆盖渐变后不吃全局（读信页信件驱动）', (tester) async {
    final controller = _FixedSkyController(_nightRainy);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [skyControllerProvider.overrideWith(() => controller)],
        child: MaterialApp(
          home: Column(
            children: [
              // 常驻订阅者：模拟真实 App 里总有页面在跟随全局天色
              //（否则无人消费时 provider 被 autoDispose，锁定无从对比）
              Offstage(
                child: Consumer(
                  builder: (_, ref, _) =>
                      Text(ref.watch(skyControllerProvider).toString()),
                ),
              ),
              Expanded(
                child: KazeSkyBox(
                  gradient: KazeSky.defaultGradient,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 全局仍是夜·雨，但画面锁定为默认昼·晴
    expect(controller.state, _nightRainy);
    expect(
      (_decoOf(tester).gradient! as LinearGradient).colors.first,
      KazeSky.defaultGradient.colors.first,
    );

    // 全局换挡也不影响锁定画面
    controller.force(
      const SkyState(weather: KazeWeather.cloudy, daypart: KazeDaypart.dusk),
    );
    await tester.pumpAndSettle();
    expect(
      (_decoOf(tester).gradient! as LinearGradient).colors.first,
      KazeSky.defaultGradient.colors.first,
    );
  });
}
