/// 写信页 —— 画布 Screen/Write（F2 最小闭环）。
///
/// 单页滚动：切换工具行 → 信纸（所见即所得）→ 图片托盘 → 表单卡
/// （地点/收信人/落款）→ 寄往何处（留/投必选）→ 寄出。P0 固定夏主题
/// 默认皮肤；AI 润色与短诗均先预览、由用户明确采纳。
///
/// 封筒态：工具行切到正放的封筒封面预览，表单区整体退场——宛名/落点/
/// 日期/天气都在封面上，是「寄出前最后看一眼这封信会以什么样子抵达」
/// 的仪式位。控制逻辑全在 [WriteController]，本文件只做布局与交互挂接。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../app/theme.dart';
import '../../app/widgets/kaze_paper_stack.dart';
import '../../app/widgets/kaze_scaffold.dart';
import '../../app/widgets/kaze_view_toggle.dart';
import '../../core/env.dart';
import '../../data/models/letter.dart';
import 'widgets/delivery_selector.dart';
import 'widgets/editable_paper.dart';
import 'widgets/meta_card.dart';
import 'widgets/photo_tray.dart';
import 'write_controller.dart';

class WriteScreen extends ConsumerStatefulWidget {
  const WriteScreen({this.parentLetterId, super.key});

  /// 非空即「回以一封信」：回信是独立作品，只是多一条溯源，
  /// **不要把它做成回复输入框**。
  final String? parentLetterId;

  @override
  ConsumerState<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends ConsumerState<WriteScreen> {
  /// 回前台即对表：日期时间立刻刷新，天气有机会也补/刷一手。
  late final AppLifecycleListener _lifecycle;

  /// 封筒封面预览态。纯视图开关，不进 [WriteState]——不参与草稿存取，
  /// 也不构成「内容变更」；工具行是封筒态唯一的返回路径。
  bool _previewEnvelope = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(writeControllerProvider.notifier).onResumed(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(writeControllerProvider.notifier)
            .start(parentLetterId: widget.parentLetterId);
      }
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(writeControllerProvider);
    final theme = Theme.of(context);

    // 控制器不持有 context：一次性提示经 notice 转发到这里弹 toast
    ref.listen(writeControllerProvider, (previous, next) {
      final notice = next.notice;
      if (notice != null && notice.seq != previous?.notice?.seq) {
        showNatsuToast(context, notice.message);
      }
    });

    return KazeScaffold(
      title: widget.parentLetterId == null ? '写信' : '回以一封信',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _viewToolbar(),
          // 顶锚换纸（默认 topCenter）：表单/封筒顶边钉在工具行正下方，
          // 高度差在下方平滑收放
          KazePaperStack(
            child: _previewEnvelope
                ? _envelopePreview(state)
                : _paperForm(state, theme),
          ),
        ],
      ),
    );
  }

  /// 纸面上方的工具行：切换钮靠左，两种视图下常驻。
  Widget _viewToolbar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: KazeSpacing.sm),
      child: Align(
        alignment: Alignment.centerLeft,
        child: KazeViewToggle(
          envelopeShown: _previewEnvelope,
          onToggle: _toggleView,
        ),
      ),
    );
  }

  /// 信纸 ↔ 封筒原地切换。切去封筒先收键盘——纸面字段回到无焦点的
  /// 静置态；文本在 controller 的 blocks 里，切回来不丢字。
  void _toggleView() {
    if (!_previewEnvelope) FocusScope.of(context).unfocus();
    setState(() => _previewEnvelope = !_previewEnvelope);
  }

  /// 封筒态：正放的封面预览。宛名/落点/日期/天气全是写信人已填的
  /// 内容，邮戳随活钟（回前台对表）刷新。
  Widget _envelopePreview(WriteState state) {
    final now = state.now;
    final addressee = state.addressee.trim();
    return Center(
      key: const ValueKey('envelope'),
      child: Padding(
        padding: const EdgeInsets.only(bottom: KazeSpacing.lg),
        child: Envelope(
          // 稳定种子：只影响邮票/邮戳的微小贴斜，每次进来一致
          seedId: 'write-preview',
          addressee: addressee.isEmpty ? null : addressee,
          place: state.dropPoint?.label ?? '风寄出的地方',
          date: '${now.month}月${now.day}日',
          weather: _weatherText(state.weather),
          tilt: 0,
          width: KazeDriftDims.envelopeW,
        ),
      ),
    );
  }

  /// 只显示天气名，不带温度（2026-08 统一口径），与漂流页/读信页一致。
  static String? _weatherText(Weather? weather) {
    if (weather == null) return null;
    return weather.text;
  }

  /// 信纸态：完整的写信滚动流（纸 → 托盘 → 表单 → 留投 → 寄出）。
  Widget _paperForm(WriteState state, ThemeData theme) {
    return Column(
      key: const ValueKey('paper'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditablePaper(onOpenPhoto: _openPhotoSheet),
        if (state.textCharCount > 0) ...[
          const SizedBox(height: KazeSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${state.textCharCount} / ${Env.letterMaxChars}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: state.textCharCount > Env.letterMaxChars
                    ? theme.colorScheme.error
                    : null,
              ),
            ),
          ),
        ],
        const SizedBox(height: KazeSpacing.sm),
        _AiAssistBar(
          hasContent: state.textCharCount > 0,
          hasPoem: state.poem != null,
          unavailable: state.aiUnavailable,
          busy: state.aiBusy,
          onPolish: _suggestPolish,
          onPoem: _suggestPoem,
          onRemovePoem: () =>
              ref.read(writeControllerProvider.notifier).clearPoem(),
        ),
        const SizedBox(height: KazeSpacing.md),
        PhotoTray(
          photos: state.photos,
          onAdd: () =>
              ref.read(writeControllerProvider.notifier).addPhotosAtCursor(),
          onOpen: _openPhotoSheet,
        ),
        const SizedBox(height: KazeSpacing.md),
        MetaCard(
          signature: state.signature,
          addressee: state.addressee,
          dropPointLabel: state.dropPoint?.label,
          locationBusy: state.locationBusy,
          onSignatureChanged: (value) =>
              ref.read(writeControllerProvider.notifier).setSignature(value),
          onAddresseeChanged: (value) =>
              ref.read(writeControllerProvider.notifier).setAddressee(value),
          onPickLocation: _pickLocation,
        ),
        const SizedBox(height: KazeSpacing.md),
        // 画布「寄往何处」眉标（12 Medium inkSoft → labelMedium 最近档）
        Padding(
          padding: const EdgeInsets.only(bottom: KazeSpacing.sm),
          child: Text('寄往何处', style: theme.textTheme.labelMedium),
        ),
        DeliverySelector(
          mode: state.deliveryMode,
          onChanged: _onDeliveryChanged,
        ),
        const SizedBox(height: KazeSpacing.lg),
        _SendButton(sending: state.sending, onPressed: _send),
      ],
    );
  }

  // ---------- 交互编排 ----------

  Future<void> _suggestPolish() async {
    FocusScope.of(context).unfocus();
    final controller = ref.read(writeControllerProvider.notifier);
    final suggestion = await controller.suggestPolish();
    if (!mounted || suggestion == null) return;
    await _showAiSuggestion(
      title: '润色后的正文',
      content: suggestion.preview,
      onAdopt: () => controller.adoptPolish(suggestion),
    );
  }

  Future<void> _suggestPoem() async {
    FocusScope.of(context).unfocus();
    final controller = ref.read(writeControllerProvider.notifier);
    final suggestion = await controller.suggestPoem();
    if (!mounted || suggestion == null) return;
    await _showAiSuggestion(
      title: '从信里找到的短诗',
      content: suggestion.poem,
      poem: true,
      onAdopt: () => controller.adoptPoem(suggestion),
    );
  }

  Future<void> _showAiSuggestion({
    required String title,
    required String content,
    required VoidCallback onAdopt,
    bool poem = false,
  }) async {
    await showNatsuDialog<void>(
      context: context,
      title: Text(title),
      body: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: SingleChildScrollView(
          child: Text(content, style: poem ? KazeLetterType.poem : null),
        ),
      ),
      actions: [
        NatsuButton(
          size: NatsuButtonSize.sm,
          variant: NatsuButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('保留原稿'),
        ),
        NatsuButton(
          size: NatsuButtonSize.sm,
          variant: NatsuButtonVariant.primary,
          onPressed: () {
            Navigator.of(context).pop();
            onAdopt();
          },
          child: const Text('采纳'),
        ),
      ],
    );
  }

  /// 选「留在这里」且还没有落点时，顺手带出落点确认——
  /// 没拿到坐标也允许先选上，寄出时的校验兜底。
  void _onDeliveryChanged(DeliveryMode mode) {
    final controller = ref.read(writeControllerProvider.notifier);
    controller.setDelivery(mode);
    if (mode == DeliveryMode.stay &&
        ref.read(writeControllerProvider).dropPoint == null) {
      _pickLocation();
    }
  }

  Future<void> _pickLocation() async {
    final controller = ref.read(writeControllerProvider.notifier);
    final candidate = await controller.acquireLocationCandidate();
    if (!mounted || candidate == null) return;
    await showNatsuSheet(
      context: context,
      title: const Text('这封信的落点'),
      child: LocationConfirmSheet(
        candidate: candidate,
        onConfirm: (label) {
          Navigator.of(context).pop();
          controller.confirmDropPoint(
            lat: candidate.lat,
            lon: candidate.lon,
            label: label,
          );
        },
      ),
    );
  }

  Future<void> _openPhotoSheet(int photoBlockId) async {
    final controller = ref.read(writeControllerProvider.notifier);
    WritePhotoBlock? photo;
    for (final block in ref.read(writeControllerProvider).blocks) {
      if (block is WritePhotoBlock && block.id == photoBlockId) photo = block;
    }
    if (!mounted || photo == null) return;

    await showNatsuSheet(
      context: context,
      child: _PhotoSheet(
        photo: photo,
        onRetry: () {
          Navigator.of(context).pop();
          controller.retryUpload(photoBlockId);
        },
        onRemove: () {
          Navigator.of(context).pop();
          controller.removePhoto(photoBlockId);
        },
      ),
    );
  }

  Future<void> _send() async {
    final owned = await ref.read(writeControllerProvider.notifier).send();
    if (!mounted || owned == null) return;
    showNatsuToast(context, '信已寄出，正在等风把它送到下一个地方');
    context.pop();
  }
}

/// 写信页 AI 辅助入口。这里只呈现状态与动作，不直接调用接口。
class _AiAssistBar extends StatelessWidget {
  const _AiAssistBar({
    required this.hasContent,
    required this.hasPoem,
    required this.unavailable,
    required this.busy,
    required this.onPolish,
    required this.onPoem,
    required this.onRemovePoem,
  });

  final bool hasContent;
  final bool hasPoem;
  final bool unavailable;
  final AiAssistKind? busy;
  final VoidCallback onPolish;
  final VoidCallback onPoem;
  final VoidCallback onRemovePoem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (unavailable) {
      return Text('AI 暂时没有回应，继续手写就好', style: theme.textTheme.bodySmall);
    }

    final enabled = hasContent && busy == null;
    return Wrap(
      spacing: KazeSpacing.sm,
      runSpacing: KazeSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        NatsuButton(
          size: NatsuButtonSize.sm,
          onPressed: enabled ? onPolish : null,
          child: _AssistLabel(
            icon: Icons.auto_fix_high_outlined,
            label: busy == AiAssistKind.polish ? '正在润色…' : 'AI 润色',
            busy: busy == AiAssistKind.polish,
          ),
        ),
        NatsuButton(
          size: NatsuButtonSize.sm,
          onPressed: enabled ? onPoem : null,
          child: _AssistLabel(
            icon: Icons.format_quote_outlined,
            label: busy == AiAssistKind.poem
                ? '正在找诗…'
                : hasPoem
                ? '重写短诗'
                : '生成短诗',
            busy: busy == AiAssistKind.poem,
          ),
        ),
        if (hasPoem)
          NatsuButton(
            size: NatsuButtonSize.sm,
            variant: NatsuButtonVariant.ghost,
            onPressed: busy == null ? onRemovePoem : null,
            child: const Text('移除短诗'),
          ),
      ],
    );
  }
}

class _AssistLabel extends StatelessWidget {
  const _AssistLabel({
    required this.icon,
    required this.label,
    required this.busy,
  });

  final IconData icon;
  final String label;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy) const NatsuSpinner(size: NatsuSpinnerSize.sm) else Icon(icon),
        const SizedBox(width: KazeSpacing.xs),
        Text(label),
      ],
    );
  }
}

/// 寄出按钮：主行动（每屏至多一个 primary）。sending 时禁用 + 邮戳环。
class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onPressed});

  final bool sending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return NatsuButton(
      variant: NatsuButtonVariant.primary,
      onPressed: sending ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (sending) ...[
            const NatsuSpinner(size: NatsuSpinnerSize.sm),
            const SizedBox(width: KazeSpacing.sm),
          ],
          Text(sending ? '寄出中…' : '寄出'),
        ],
      ),
    );
  }
}

/// 照片操作弹层：大图预览 + （失败时）重试 + 移除。
class _PhotoSheet extends StatelessWidget {
  const _PhotoSheet({
    required this.photo,
    required this.onRetry,
    required this.onRemove,
  });

  final WritePhotoBlock photo;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(KazeRadius.card),
          child: Image.file(
            File(photo.localPath),
            height: 280,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: KazeSpacing.md),
        Text(switch (photo.phase) {
          PhotoUploadPhase.pending => '还在排队上传…',
          PhotoUploadPhase.uploading => '正在上传…',
          PhotoUploadPhase.uploaded => '已经夹进信里了',
          PhotoUploadPhase.failed => '没有传上去',
        }, style: theme.textTheme.bodySmall),
        const SizedBox(height: KazeSpacing.md),
        if (photo.phase == PhotoUploadPhase.failed) ...[
          NatsuButton(
            variant: NatsuButtonVariant.primary,
            onPressed: onRetry,
            child: const Text('重新上传'),
          ),
          const SizedBox(height: KazeSpacing.sm),
        ],
        NatsuButton(
          variant: NatsuButtonVariant.secondary,
          onPressed: onRemove,
          child: const Text('移除这张照片'),
        ),
      ],
    );
  }
}
