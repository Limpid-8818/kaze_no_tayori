/// 就地发掘页 —— 定位半径内「留在这里」的信，时间序列表。
///
/// 布局纪律：与其他页一致的默认 KazeScaffold（画布大标题为设计疏漏，
/// 用户裁决不实现），卡片直排无歪斜。定位统一走 LocationController，
/// 拒绝时给「重试 / 去设置」，不用默认坐标。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../app/controllers/home_environment_controller.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../app/widgets/kaze_scaffold.dart';
import '../../app/widgets/letter_summary_card.dart';
import '../../app/widgets/narrative_card.dart';
import '../../core/env.dart';
import 'discover_controller.dart';
import 'discover_view.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with RouteAware {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(discoverControllerProvider.notifier).start();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 从阅读器返回（点开即已读）时整页重刷：服务端本就排除已读信，
    // 列表不该再出现刚读完的那封。
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    ref.read(discoverControllerProvider.notifier).start();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverControllerProvider);
    final controller = ref.read(discoverControllerProvider.notifier);

    return KazeScaffold(
      title: '就地发掘',
      scrollable: false,
      body: switch (state.phase) {
        DiscoverPhase.serviceDisabled => NarrativeCard(
          title: '定位服务没有开',
          subtitle: '在系统设置里打开定位，再来找找',
          actionLabel: '去设置',
          onAction: () => controller.openSettingsThenRetry(),
          secondaryLabel: '再试一次',
          onSecondaryAction: () => controller.start(),
        ),
        DiscoverPhase.permissionDenied => _deniedCard(() => controller.start()),
        DiscoverPhase.permissionPermanentlyDenied => _deniedCard(
          controller.openSettingsThenRetry,
        ),
        DiscoverPhase.locating || DiscoverPhase.listLoading
            when state.items.isEmpty =>
          _LocatingBody(phase: state.phase),
        DiscoverPhase.listEmpty => NarrativeCard(
          title: '附近还没有埋下的信',
          subtitle: '换个大点的圈子，或者晚点再来',
          actionLabel: '刷新',
          onAction: () => controller.refresh(),
        ),
        DiscoverPhase.error => NarrativeCard(
          title: '没能拿到附近的信',
          subtitle: '检查网络后再试一次',
          actionLabel: '再试一次',
          onAction: () => controller.start(),
        ),
        _ => _ListBody(items: state.items, onOpenLetter: _open),
      },
    );
  }

  /// 拒绝态：解释 + 重试 + 去设置（permanentlyDenied 时主动作换跳系统设置）。
  Widget _deniedCard(GestureTapCallback settingsAction) {
    return NarrativeCard(
      title: '没有拿到定位权限',
      subtitle: '允许定位后，就能看到附近埋着的信',
      actionLabel: '去设置',
      onAction: settingsAction,
      secondaryLabel: '再试一次',
      onSecondaryAction: () =>
          ref.read(discoverControllerProvider.notifier).start(),
    );
  }

  // 点列表卡 = 决定拆这封；markRead 由阅读器完成，本页不发已读请求。
  void _open(BuildContext context, String letterId) =>
      context.push(Routes.readerOf(letterId));
}

// ---------------------------------------------------------------------

/// 定位中/检索中的过渡态（首次进入，列表还没有内容）。
class _LocatingBody extends StatelessWidget {
  const _LocatingBody({required this.phase});

  final DiscoverPhase phase;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NatsuSpinner(),
          const SizedBox(height: KazeSpacing.sm),
          Text(
            phase == DiscoverPhase.locating ? '正在找到你的位置' : '正在翻找附近的信',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// ready 态：定位卡 + 摘要卡列表（下拉刷新）。
class _ListBody extends ConsumerWidget {
  const _ListBody({required this.items, required this.onOpenLetter});

  final List<DiscoverLetterView> items;
  final void Function(BuildContext, String) onOpenLetter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeLabel = ref.watch(
      homeEnvironmentControllerProvider.select((s) => s.placeLabel),
    );
    return Column(
      children: [
        _LocationHeader(
          placeLabel: placeLabel,
          meta: '半径 ${_radiusLabel()} · 找到 ${items.length} 封信',
        ),
        const SizedBox(height: KazeSpacing.md),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(discoverControllerProvider.notifier).refresh(),
            child: ListView.separated(
              // 下拉刷新需要列表可越界拖动
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: KazeSpacing.sm),
              itemBuilder: (context, index) {
                final view = items[index];
                return LetterSummaryCard(
                  timeLabel: view.timeLabel,
                  poem: view.poemLines.join('\n'),
                  previewText: view.previewText,
                  placeLabel: view.placeLabel,
                  onTap: () => onOpenLetter(context, view.id),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// 半径预设的展示口径：「1000m」→「1km」，其余保持米。
String _radiusLabel() {
  const m = Env.discoverRadiusM;
  return m >= 1000 && m % 1000 == 0 ? '${m ~/ 1000}km' : '$m';
}

/// 头部定位卡（画布 Screen/Discover 的 LocationCard，直排版）。
class _LocationHeader extends StatelessWidget {
  const _LocationHeader({required this.placeLabel, required this.meta});

  /// 逆地理地名；取不到就用通用称呼，不阻断列表。
  final String? placeLabel;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: KazeDiscoverDims.locCardH,
      padding: const EdgeInsets.symmetric(horizontal: KazeSpacing.md),
      decoration: BoxDecoration(
        color: KazeColors.envelope,
        borderRadius: BorderRadius.circular(KazeDiscoverDims.locCardRadius),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 24,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: KazeSpacing.sm + KazeSpacing.xs),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  placeLabel ?? '附近',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // 画布 14 Medium；bodyLarge(16) 缩一档（偏差记录）
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 14),
                ),
                Text(
                  meta,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: KazeColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
