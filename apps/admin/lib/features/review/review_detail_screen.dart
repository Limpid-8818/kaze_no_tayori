/// 审核详情：左「读者视角预览」+ 右操作面板（元信息/计数/状态流转）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/result.dart';
import '../../data/api/providers.dart';
import '../../data/models/admin.dart';
import '../../data/models/enums.dart';
import '../../shared/letter_preview_panel.dart';
import '../../shared/widgets.dart' show confirmAction, showNotice, StatusBadge;
import 'letter_list_controller.dart'
    show lettersListProvider, reviewListProvider;

enum DetailPhase { loading, ready, notFound, error }

class ReviewDetailState {
  const ReviewDetailState({this.phase = DetailPhase.loading, this.detail});

  final DetailPhase phase;
  final AdminLetterDetail? detail;
}

class ReviewDetailController extends Notifier<ReviewDetailState> {
  ReviewDetailController(this.arg);

  final String arg;

  @override
  ReviewDetailState build() => const ReviewDetailState();

  Future<void> start() async {
    try {
      final detail = await ref.read(adminApiProvider).letter(arg);
      if (!ref.mounted) return;
      state = ReviewDetailState(phase: DetailPhase.ready, detail: detail);
    } on ApiFailure catch (e) {
      if (!ref.mounted) return;
      state = ReviewDetailState(
        phase: e.kind == ApiErrorKind.notFound
            ? DetailPhase.notFound
            : DetailPhase.error,
      );
    }
  }

  /// 状态流转。成功后详情与列表（review/letters）一起刷新。
  /// 返回 (ok, errorMessage)。
  Future<(bool, String?)> transitionTo(LetterStatus to) async {
    try {
      final detail = await ref.read(adminApiProvider).transitionLetter(arg, to);
      if (!ref.mounted) return (false, null);
      state = ReviewDetailState(phase: DetailPhase.ready, detail: detail);
      await Future.wait<void>([
        ref.read(reviewListProvider.notifier).refresh(),
        // letters 列表可能尚未实例化（未进过页面），异常静默
        ref.read(lettersListProvider.notifier).refresh(),
      ]);
      return (true, null);
    } on ApiFailure catch (e) {
      if (ref.mounted) state = ReviewDetailState(phase: DetailPhase.ready);
      return (false, e.message);
    }
  }
}

final reviewDetailControllerProvider =
    NotifierProvider.family<ReviewDetailController, ReviewDetailState, String>(
      ReviewDetailController.new,
    );

class ReviewDetailScreen extends ConsumerStatefulWidget {
  const ReviewDetailScreen({super.key, required this.letterId});

  final String letterId;

  @override
  ConsumerState<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends ConsumerState<ReviewDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(reviewDetailControllerProvider(widget.letterId).notifier)
          .start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewDetailControllerProvider(widget.letterId));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(AdminRoutes.review)),
        title: const Text('审核信件'),
      ),
      body: switch (state.phase) {
        DetailPhase.loading => const Center(child: CircularProgressIndicator()),
        DetailPhase.notFound => const Center(child: Text('信不存在（可能已删除）')),
        DetailPhase.error => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('加载失败'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref
                    .read(
                      reviewDetailControllerProvider(widget.letterId).notifier,
                    )
                    .start(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        DetailPhase.ready when state.detail == null => const SizedBox.shrink(),
        DetailPhase.ready => _Body(
          letterId: widget.letterId,
          detail: state.detail!,
        ),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.letterId, required this.detail});

  final String letterId;
  final AdminLetterDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      reviewDetailControllerProvider(letterId).notifier,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 左栏：读者视角预览
        Expanded(flex: 3, child: LetterPreviewPanel(detail: detail)),
        const VerticalDivider(width: 1),
        // 右栏：操作面板
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    StatusBadge(status: detail.status),
                    const Spacer(),
                    Text(
                      '读${detail.counts.read} · 鸣${detail.counts.resonance} · '
                      '声${detail.counts.voice} · 回${detail.counts.reply} · '
                      '藏${detail.counts.saved}',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _MetaTable(detail: detail),
                const SizedBox(height: 24),
                _Actions(detail: detail, onTransition: controller.transitionTo),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaTable extends StatelessWidget {
  const _MetaTable({required this.detail});

  final AdminLetterDetail detail;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('投放', detail.deliveryMode == DeliveryMode.stay ? '留在原地' : '投递漂流'),
      ('落点', detail.placeLabel ?? '—'),
      (
        '坐标',
        detail.lat != null
            ? '${detail.lat!.toStringAsFixed(4)}, ${detail.lon!.toStringAsFixed(4)}'
            : '—',
      ),
      ('天气', detail.weather?.text ?? '—'),
      ('署名', detail.signature ?? '（未署名）'),
      ('宛名', detail.addressee ?? '（无）'),
      ('主题', detail.themeId),
      ('种子信', detail.ownerUserId == null ? '是（无主）' : '否'),
      ('owner', detail.ownerUserId ?? '—'),
      (
        '时间',
        '${detail.createdAt.year}-${detail.createdAt.month}-${detail.createdAt.day}',
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.detail, required this.onTransition});

  final AdminLetterDetail detail;
  final Future<(bool, String?)> Function(LetterStatus) onTransition;

  @override
  Widget build(BuildContext context) {
    final children = switch (detail.status) {
      LetterStatus.pending => [
        FilledButton(
          onPressed: () => _run(
            context,
            LetterStatus.public,
            title: '通过这封信？',
            message: '通过后即刻进入公开水域，读者可读。',
          ),
          child: const Text('通过'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: () => _run(
            context,
            LetterStatus.rejected,
            title: '驳回这封信？',
            message: '驳回是终态；后续可赦免回公开。',
          ),
          child: const Text('驳回'),
        ),
      ],
      LetterStatus.public => [
        FilledButton.tonal(
          onPressed: () => _run(
            context,
            LetterStatus.takenDown,
            title: '下架这封信？',
            message: '下架后读者侧立即 404；可随时恢复。',
          ),
          child: const Text('下架'),
        ),
      ],
      LetterStatus.takenDown => [
        FilledButton(
          onPressed: () => _run(
            context,
            LetterStatus.public,
            title: '恢复公开？',
            message: '这封信将重新进入公开水域。',
          ),
          child: const Text('恢复公开'),
        ),
      ],
      LetterStatus.rejected => [
        FilledButton.tonal(
          onPressed: () => _run(
            context,
            LetterStatus.public,
            title: '赦免这封信？',
            message: '赦免将把驳回的信放回公开水域。',
          ),
          child: const Text('赦免'),
        ),
      ],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Future<void> _run(
    BuildContext context,
    LetterStatus to, {
    required String title,
    required String message,
  }) async {
    final ok = await confirmAction(context, title: title, message: message);
    if (!ok) return;
    final (success, error) = await onTransition(to);
    if (!context.mounted) return;
    if (success) {
      showNotice(
        context,
        '已更新为「${switch (to) {
          LetterStatus.public => '公开',
          LetterStatus.rejected => '已驳回',
          LetterStatus.takenDown => '已下架',
          LetterStatus.pending => '待审核',
        }}」',
      );
    } else if (error != null) {
      showNotice(context, error);
    }
  }
}
