/// 反馈页 — 设置页「帮助与反馈」入口的目标页。
///
/// 一张信纸卡：手写引导语 → 类型单选（问题/建议）→ 多行输入 → 寄出。
/// 提交成功切确认态，点「好的」返回。未来功能成熟后此页升级为
/// 「帮助与反馈」独立入口的子页，视觉骨架保持不变。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../app/theme.dart';
import '../../app/widgets/kaze_scaffold.dart';
import '../../data/api/feedback_api.dart';
import 'feedback_store.dart';

class FeedbackScreen extends ConsumerWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submitted = ref.watch(feedbackProvider.select((s) => s.submitted));

    return KazeScaffold(
      title: '反馈',
      body: submitted ? const _SuccessCard() : const _FeedbackFormCard(),
    );
  }
}

/// 信纸卡外框：与关于页同一纸影写法（墨蓝 14%，向下 6 晕开 24）。
class _PaperCard extends StatelessWidget {
  const _PaperCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(KazeRadius.card),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.14),
            offset: const Offset(0, 6),
            blurRadius: 24,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(KazeSpacing.lg),
        child: child,
      ),
    );
  }
}

class _FeedbackFormCard extends ConsumerStatefulWidget {
  const _FeedbackFormCard();

  @override
  ConsumerState<_FeedbackFormCard> createState() => _FeedbackFormCardState();
}

class _FeedbackFormCardState extends ConsumerState<_FeedbackFormCard> {
  /// 正文与 state.content 同源：state 是唯一事实，controller 只承载
  /// 光标/ composing 等编辑态。外部不会程序性改写正文，无回路风险。
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  static const _kinds = <(FeedbackCategory, String, String)>[
    (FeedbackCategory.bug, '遇到的问题', '哪里用不了、哪里不对劲'),
    (FeedbackCategory.suggestion, '改进建议', '想要什么功能、哪里能更好'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(feedbackProvider);
    final controller = ref.read(feedbackProvider.notifier);

    return _PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('把路上的坑洼与心愿写给风，\n我们会一封封读。', style: NatsuTypography.hwNote),
          const SizedBox(height: KazeSpacing.lg),
          ..._kinds.map(
            (kind) => InkWell(
              onTap: () => controller.setCategory(kind.$1),
              borderRadius: BorderRadius.circular(KazeRadius.card),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: KazeSpacing.sm),
                child: Row(
                  children: [
                    NatsuRadio<FeedbackCategory>(
                      value: kind.$1,
                      groupValue: state.category,
                      onChanged: controller.setCategory,
                    ),
                    const SizedBox(width: KazeSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(kind.$2, style: theme.textTheme.titleMedium),
                          Text(kind.$3, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: KazeSpacing.sm),
          TextField(
            controller: _textController,
            onChanged: controller.setContent,
            maxLines: 6,
            minLines: 6,
            maxLength: 2000,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: '说说你的问题或想法',
              counterStyle: theme.textTheme.bodySmall,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(KazeRadius.card),
              ),
            ),
          ),
          const SizedBox(height: KazeSpacing.md),
          if (state.errorMessage case final message?) ...[
            Text(
              message,
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: KazeSpacing.sm),
          ],
          NatsuButton(
            variant: NatsuButtonVariant.primary,
            onPressed: state.canSubmit ? controller.submit : null,
            child: state.submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('寄出反馈'),
          ),
        ],
      ),
    );
  }
}

/// 提交确认态：一句回执 + 返回。
class _SuccessCard extends StatelessWidget {
  const _SuccessCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PaperCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: KazeSpacing.md),
          const Text('已经寄到了。', style: NatsuTypography.hwNote),
          const SizedBox(height: KazeSpacing.xs),
          Text('谢谢你的声音，我们会认真读。', style: theme.textTheme.bodySmall),
          const SizedBox(height: KazeSpacing.lg),
          NatsuButton(
            variant: NatsuButtonVariant.primary,
            onPressed: () => context.pop(),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }
}
