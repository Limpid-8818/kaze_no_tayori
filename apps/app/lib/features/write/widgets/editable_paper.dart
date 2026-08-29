/// 信纸（所见即所得）—— 组件库 LetterReading 的编辑态等价物。
///
/// 纸面纪律与 LetterReading 完全一致（画布 Screen/Write 的信件部分
/// 与组件库出入时，以组件库为准）：paperWhite 底、radius 2、发丝线、
/// letterResting 影、padding 40/44/40/32、hwBody 20/38、照片 72% 宽
/// 居中、署名右下 hwAddress、meta 行右对齐。差别只有：文本段是可编辑的
/// TextField（编辑态照片完全端正 tilt:0），以及插完照片后的焦点回归。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../../app/theme.dart';
import '../../../core/day_period.dart';
import '../write_controller.dart';

class EditablePaper extends ConsumerStatefulWidget {
  const EditablePaper({required this.onOpenPhoto, super.key});

  /// 点纸面照片（与托盘缩略图同一个弹层）。
  final void Function(int photoBlockId) onOpenPhoto;

  @override
  ConsumerState<EditablePaper> createState() => _EditablePaperState();
}

class _EditablePaperState extends ConsumerState<EditablePaper> {
  final Map<int, _FieldHandle> _fields = {};

  @override
  void initState() {
    super.initState();
    // 焦点请求（插完照片光标回正文断点）——listenManual 而非 build 里的
    // ref.listen：焦点操作不该跟着重建走
    ref.listenManual(writeControllerProvider, (previous, next) {
      final request = next.focusRequest;
      if (request != null && request.seq != previous?.focusRequest?.seq) {
        _fields[request.blockId]?.focus(offset: request.offset);
      }
    });
  }

  void _register(int blockId, _FieldHandle? handle) {
    if (handle == null) {
      _fields.remove(blockId);
    } else {
      _fields[blockId] = handle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(writeControllerProvider);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // LetterReading 纪律：照片宽 = 纸宽 × 0.72 居中
        final photoWidth = constraints.maxWidth * 0.72;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(40, 44, 40, 32),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(KazeRadius.letter),
            border: Border.all(color: theme.colorScheme.outline),
            boxShadow: KazeLetterShadows.resting,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, block) in state.blocks.indexed) ...[
                if (index > 0) const SizedBox(height: KazeSpacing.lg),
                switch (block) {
                  WriteTextBlock() => _EditableTextBlock(
                    key: ValueKey<int>(block.id),
                    blockId: block.id,
                    text: block.text,
                    showHint: index == 0,
                    onChanged: (value) {
                      ref
                          .read(writeControllerProvider.notifier)
                          .updateText(block.id, value);
                    },
                    onCursor: (offset) => ref
                        .read(writeControllerProvider.notifier)
                        .reportCursor(block.id, offset),
                    onRegister: _register,
                  ),
                  WritePhotoBlock() => _PaperPhoto(
                    photo: block,
                    width: photoWidth,
                    onTap: () => widget.onOpenPhoto(block.id),
                  ),
                },
              ],
              if (state.poem != null) ...[
                const SizedBox(height: KazeSpacing.lg),
                Text(state.poem!, style: KazeLetterType.poem),
              ],
              // 落款实时渲染：表单里输入的同时落在纸上（右下横排 hwAddress）
              if (state.signature.trim().isNotEmpty) ...[
                const SizedBox(height: KazeSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    state.signature.trim(),
                    style: NatsuTypography.hwAddress,
                  ),
                ),
              ],
              ..._metaLine(state),
            ],
          ),
        );
      },
    );
  }

  /// 纸尾 meta 行：地点（已确认落点）· 日期（只到日，与读信页/邮戳
  /// 同口径）· 时段 · 天气（可降级省略）。
  List<Widget> _metaLine(WriteState state) {
    final now = state.now;
    final items = [
      ?state.dropPoint?.label,
      '${now.month}月${now.day}日',
      dayPeriodLabel(dayPeriodOf(now)),
      ?state.weather?.text,
    ];
    if (items.isEmpty) return const [];
    return [
      const SizedBox(height: KazeSpacing.lg),
      Align(
        alignment: Alignment.centerRight,
        child: NatsuMetaLine(items: items),
      ),
    ];
  }
}

// ---------- 可编辑文本段 ----------

/// 一个文本段一个字段。controller/focusNode 由 State 持有，
/// 外部文本变化（恢复草稿）只在字段未聚焦时回写——自己敲的字不回写，
/// 否则光标会跳。
class _EditableTextBlock extends StatefulWidget {
  const _EditableTextBlock({
    required this.blockId,
    required this.text,
    required this.showHint,
    required this.onChanged,
    required this.onCursor,
    required this.onRegister,
    super.key,
  });

  final int blockId;
  final String text;
  final bool showHint;
  final ValueChanged<String> onChanged;
  final ValueChanged<int> onCursor;
  final void Function(int blockId, _FieldHandle? handle) onRegister;

  @override
  State<_EditableTextBlock> createState() => _EditableTextBlockState();
}

class _FieldHandle {
  _FieldHandle(this.controller, this.focusNode);

  final TextEditingController controller;
  final FocusNode focusNode;

  /// focus() 想要的偏移；文本可能随同一次状态变化还没跟上（比如移除
  /// 照片后的缝合段变长了），留给 didUpdateWidget 在新文本上补落位。
  int? pendingOffset;

  void focus({int offset = 0}) {
    focusNode.requestFocus();
    pendingOffset = offset;
    final clamped = offset.clamp(0, controller.text.length);
    controller.selection = TextSelection.collapsed(offset: clamped);
  }
}

class _EditableTextBlockState extends State<_EditableTextBlock> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  )..addListener(_onControllerChanged);
  late final FocusNode _focusNode = FocusNode();
  late final _FieldHandle _handle = _FieldHandle(_controller, _focusNode);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_reportCursor);
    widget.onRegister(widget.blockId, _handle);
  }

  /// 文本与选区变化都经此（controller 对 value 整体通知）。
  /// 回写有守卫：controller 文本与 widget.text 一致时不算用户输入——
  /// 程序性动作（设选区、回写草稿/缝合结果）也会触发通知，若照单
  /// 全收会把外部刚写进 state 的新内容用旧文本盖掉（吞字段事故）。
  void _onControllerChanged() {
    if (_controller.text != widget.text) {
      widget.onChanged(_controller.text);
    }
    _reportCursor();
  }

  @override
  void didUpdateWidget(covariant _EditableTextBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != _controller.text) {
      final offset = _focusNode.hasFocus
          ? _controller.selection.baseOffset.clamp(0, widget.text.length)
          : widget.text.length;
      _controller.value = TextEditingValue(
        text: widget.text,
        selection: TextSelection.collapsed(offset: offset),
      );
    }
    // focus 请求到的偏移若被旧文本截短过，在新文本上补落位（缝点精确）
    final pending = _handle.pendingOffset;
    if (pending != null) {
      _handle.pendingOffset = null;
      _controller.selection = TextSelection.collapsed(
        offset: pending.clamp(0, widget.text.length),
      );
    }
  }

  @override
  void dispose() {
    widget.onRegister(widget.blockId, null);
    _controller.removeListener(_onControllerChanged);
    _focusNode.removeListener(_reportCursor);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _reportCursor() {
    if (!_focusNode.hasFocus) return;
    final offset = _controller.selection.baseOffset;
    if (offset >= 0) widget.onCursor(offset);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      style: NatsuTypography.hwBody,
      cursorColor: theme.colorScheme.secondary,
      maxLines: null,
      minLines: 1,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        isCollapsed: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintText: widget.showHint ? '此刻想写的话……' : null,
        hintStyle: NatsuTypography.hwBody.copyWith(color: KazeColors.inkFaint),
      ),
    );
  }
}

// ---------- 纸面照片 ----------

class _PaperPhoto extends StatelessWidget {
  const _PaperPhoto({
    required this.photo,
    required this.width,
    required this.onTap,
  });

  final WritePhotoBlock photo;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Stack(
          children: [
            // 编辑态完全端正（seedId 只承担颗粒/光带的确定性）
            PhotoCard(
              image: FileImage(File(photo.localPath)),
              seedId: 'draft-${photo.id}',
              tilt: 0,
              width: width,
              height: width * 0.7,
            ),
            switch (photo.phase) {
              PhotoUploadPhase.pending ||
              PhotoUploadPhase.uploading => Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(KazeRadius.letter),
                  child: ColoredBox(
                    color: theme.colorScheme.surface.withValues(alpha: 0.55),
                    child: const Center(child: NatsuSpinner()),
                  ),
                ),
              ),
              PhotoUploadPhase.failed => Positioned(
                right: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(KazeRadius.card),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KazeSpacing.sm,
                      vertical: KazeSpacing.xs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 14,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: KazeSpacing.xs),
                        Text(
                          '没传上，点开重试',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              PhotoUploadPhase.uploaded => const SizedBox.shrink(),
            },
          ],
        ),
      ),
    );
  }
}
