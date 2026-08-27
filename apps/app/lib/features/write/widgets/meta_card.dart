/// 表单卡 —— 画布 Screen/Write 的 MetaCard：地点 / 收信人 / 落款 三行。
///
/// 地点是「点击 → 定位候选 → 弹层确认」的落点入口（消费全局
/// LocationController，改地名不改坐标）；收信人与落款是内联输入
/// （宛名只上封筒、不落纸面，故不做实时渲染；落款由信纸实时渲染）。
library;

import 'package:flutter/material.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../../app/theme.dart';
import '../../../core/env.dart';
import '../write_controller.dart';

class MetaCard extends StatelessWidget {
  const MetaCard({
    required this.signature,
    required this.addressee,
    required this.dropPointLabel,
    required this.locationBusy,
    required this.onSignatureChanged,
    required this.onAddresseeChanged,
    required this.onPickLocation,
    super.key,
  });

  final String signature;
  final String addressee;
  final String? dropPointLabel;
  final bool locationBusy;
  final ValueChanged<String> onSignatureChanged;
  final ValueChanged<String> onAddresseeChanged;
  final VoidCallback onPickLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(KazeRadius.card),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MetaRow(
            label: '地点',
            child: _LocationValue(
              label: dropPointLabel,
              busy: locationBusy,
              onTap: onPickLocation,
            ),
          ),
          const Divider(height: 1, thickness: 1),
          _MetaRow(
            label: '收信人',
            child: _MetaInput(
              value: addressee,
              hint: '选填 · 致 远方的你',
              maxLength: Env.addresseeMaxChars,
              onChanged: onAddresseeChanged,
            ),
          ),
          const Divider(height: 1, thickness: 1),
          _MetaRow(
            label: '落款',
            child: _MetaInput(
              value: signature,
              hint: '选填 · 不留名也可以',
              maxLength: Env.signatureMaxChars,
              onChanged: onSignatureChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: KazeWriteDims.metaRowH,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KazeSpacing.md),
        child: Row(
          children: [
            SizedBox(
              width: KazeWriteDims.metaLabelW,
              child: Text(label, style: theme.textTheme.labelMedium),
            ),
            const SizedBox(width: KazeSpacing.md),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// 地点行：值或占位 + 定位中的邮戳环。
class _LocationValue extends StatelessWidget {
  const _LocationValue({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String? label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (busy) {
      return Row(
        children: [
          const NatsuSpinner(size: NatsuSpinnerSize.sm),
          const SizedBox(width: KazeSpacing.sm),
          Text('定位中…', style: theme.textTheme.bodyMedium),
        ],
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Flexible(
            child: Text(
              label ?? '点击选一个落点（可选）',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: label == null
                  ? theme.textTheme.bodyMedium
                  : theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: KazeSpacing.xs),
            Icon(Icons.edit_outlined, size: 16, color: KazeColors.inkFaint),
          ],
        ],
      ),
    );
  }
}

/// 收信人/落款行：内联无边框输入，占位与值同排。
class _MetaInput extends StatefulWidget {
  const _MetaInput({
    required this.value,
    required this.hint,
    required this.maxLength,
    required this.onChanged,
  });

  final String value;
  final String hint;
  final int maxLength;
  final ValueChanged<String> onChanged;

  @override
  State<_MetaInput> createState() => _MetaInputState();
}

class _MetaInputState extends State<_MetaInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant _MetaInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      final offset = _controller.selection.baseOffset;
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(
          offset: offset >= 0 ? offset.clamp(0, widget.value.length) : 0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      cursorColor: theme.colorScheme.secondary,
      maxLength: widget.maxLength,
      decoration: _bare(context, hint: widget.hint),
    );
  }
}

/// 共用的无边框 InputDecoration（主题的 filled/border 全部显式关掉）。
InputDecoration _bare(BuildContext context, {String? hint}) {
  final theme = Theme.of(context);
  return InputDecoration(
    isCollapsed: true,
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    counterText: '',
    hintText: hint,
    hintStyle: theme.textTheme.bodyMedium,
  );
}

// ---------- 落点确认弹层 ----------

/// 落点确认：展示候选坐标、允许改名（改名不改坐标），确认后写入落点。
/// 经 showNatsuSheet 弹出——纯 widgets 路由，TextField 需要一层透明
/// Material 祖先。
class LocationConfirmSheet extends StatefulWidget {
  const LocationConfirmSheet({
    required this.candidate,
    required this.onConfirm,
    super.key,
  });

  final LocationCandidate candidate;
  final void Function(String label) onConfirm;

  @override
  State<LocationConfirmSheet> createState() => _LocationConfirmSheetState();
}

class _LocationConfirmSheetState extends State<LocationConfirmSheet> {
  late final TextEditingController _label = TextEditingController(
    text: widget.candidate.label ?? '',
  );

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidate = widget.candidate;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '坐标 ${candidate.lat.toStringAsFixed(4)}, '
            '${candidate.lon.toStringAsFixed(4)}',
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: KazeSpacing.md),
          TextField(
            controller: _label,
            maxLength: Env.placeLabelMaxChars,
            cursorColor: theme.colorScheme.secondary,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              labelText: '地点名',
              hintText: '给这个地方起个名字',
              counterStyle: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: KazeSpacing.sm),
          Text(
            '改地名不会改变坐标；只有地名、没有坐标的信不能「留在这里」。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: KazeSpacing.lg),
          NatsuButton(
            variant: NatsuButtonVariant.primary,
            onPressed: () => widget.onConfirm(_label.text),
            child: const Text('就落在这里'),
          ),
        ],
      ),
    );
  }
}
