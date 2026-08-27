/// 读信页固定底部操作栏：✦ 共鸣 | 回一封信。
///
/// 常驻底部：长信滚到底操作也始终可达。共鸣用设计系统的 NatsuResonance
/// 受控组件（句子式计数自带）；回信是主行动，每屏至多一个 primary。
/// 举报 / 查看原信不放这里——在 AppBar 的「⋯」菜单（见 ReaderScreen）。
library;

import 'package:flutter/material.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../../app/theme.dart';

class ReaderActionBar extends StatelessWidget {
  const ReaderActionBar({
    required this.resonated,
    required this.resonanceCount,
    required this.onResonate,
    required this.onReply,
    super.key,
  });

  final bool resonated;
  final int resonanceCount;
  final VoidCallback onResonate;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: KazeColors.iconWell, width: 1)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KazeSpacing.md,
            vertical: KazeSpacing.sm,
          ),
          child: Row(
            children: [
              // 长句式计数在窄屏放不下时整体缩放，不溢出
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: NatsuResonance(
                    count: resonanceCount,
                    resonated: resonated,
                    onResonate: onResonate,
                  ),
                ),
              ),
              const SizedBox(width: KazeSpacing.sm),
              NatsuButton(
                variant: NatsuButtonVariant.primary,
                onPressed: onReply,
                child: const Text('回一封信'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
