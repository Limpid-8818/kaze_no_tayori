/// 审核预览双栏的左栏：读者视角的信件渲染。
///
/// 背景用浅色环境底（读者侧读信页的天空环境层此处以中性浅底代替，
/// 避免管理端引入天色联动）；信纸复用 `LetterReading`（宽 432 与
/// 读者侧导出/阅读一致）。这是 theme.dart 之外唯一显式取用信件渲染
/// 组件的位置（docs/ADMIN_CONSOLE.md §1 例外）。
library;

import 'package:flutter/material.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart' as natsu;

import '../data/models/admin.dart';
import 'admin_letter_view.dart';

class LetterPreviewPanel extends StatelessWidget {
  const LetterPreviewPanel({super.key, required this.detail});

  final AdminLetterDetail detail;

  @override
  Widget build(BuildContext context) {
    final view = AdminLetterView.from(detail);
    final poem = detail.poem?.trim();
    final hasPoem = poem != null && poem.isNotEmpty;
    return Container(
      color: const Color(0xFFE8F1F7),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              natsu.LetterReading(
                blocks: view.blocks,
                photoResolver: adminPhotoResolver,
                width: 432,
                place: view.place,
                time: view.timeLabel,
                dayPeriod: view.dayPeriod,
                weather: view.weatherText,
                signature: view.signature,
              ),
              // 短诗与正文同屏（读信页 LetterContent 同款结构：正文纸下
              // 挂一张小卡）；管理端用 Material 卡片近似，不引信件天色。
              if (hasPoem) ...[
                const SizedBox(height: 8),
                Container(
                  width: 432,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    poem,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(height: 1.8, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
