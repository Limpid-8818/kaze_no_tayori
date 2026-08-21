/// 首页：两条收信入口 + 写信。
///
/// 脚手架期还挂了一张「后端连通性」卡片，用来验证 App ↔ API 打通
/// （见 docs/DEV_SETUP.md）。功能开发起来后应当移除它。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/env.dart';
import '../data/api/api_client.dart';
import '../core/result.dart';
import 'router.dart';
import 'theme.dart';

/// 脚手架期的连通性探针。功能开发完成后连同卡片一起删掉。
final _healthProvider = FutureProvider<String>((ref) async {
  final client = ApiClient();
  final json = await client.getJson('/health');
  return json['status'] as String? ?? 'unknown';
});

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        // 环境是夏日天空，纸只在「信」的时候出现
        decoration: const BoxDecoration(gradient: KazeTheme.skyGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    Text('风信', style: theme.textTheme.displayLarge),
                    const SizedBox(height: 8),
                    Text('让作品先于作者抵达', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 48),

                    // 两条收信入口，并列的一等公民
                    FilledButton(
                      onPressed: () => context.push(Routes.drift),
                      child: const Text('随机漂流'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.push(Routes.discover),
                      child: const Text('就地发掘'),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () => context.push(Routes.write),
                      child: const Text('写一封信'),
                    ),

                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => context.push(Routes.myLetters),
                          child: const Text('我的信'),
                        ),
                        TextButton(
                          onPressed: () => context.push(Routes.scripbook),
                          child: const Text('抄本'),
                        ),
                        TextButton(
                          onPressed: () => context.push(Routes.notifications),
                          child: const Text('回信告知'),
                        ),
                        TextButton(
                          onPressed: () => context.push(Routes.settings),
                          child: const Text('设置'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                    const _HealthCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 脚手架期的后端连通性卡片。
class _HealthCard extends ConsumerWidget {
  const _HealthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final health = ref.watch(_healthProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('后端连通性（脚手架自检）', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(Env.apiBaseUrl, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            switch (health) {
              AsyncData(:final value) => Text(
                '/health → $value',
                style: theme.textTheme.bodyLarge,
              ),
              AsyncError(:final error) => Text(
                error is ApiFailure ? error.message : '连不上后端',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              _ => const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            },
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(_healthProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
