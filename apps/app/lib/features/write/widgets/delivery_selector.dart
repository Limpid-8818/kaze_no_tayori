/// 寄往何处 —— 留/投二选一（画布 Screen/Write 的 DeliveryRow）。
///
/// PRD 6.1：这一步**必选**，不许有默认值悄悄带过。未选中时两张卡
/// 同为纸底发丝线的中性态；选中 = 墨蓝填充暖白字（两卡同款选中态，
/// 全程令牌化）。
library;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models/letter.dart';

class DeliverySelector extends StatelessWidget {
  const DeliverySelector({
    required this.mode,
    required this.onChanged,
    super.key,
  });

  final DeliveryMode? mode;
  final ValueChanged<DeliveryMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: KazeWriteDims.deliveryCardH,
      child: Row(
        children: [
          Expanded(
            child: _DeliveryCard(
              selected: mode == DeliveryMode.stay,
              icon: Icons.location_on_outlined,
              title: '留在这里',
              description: '埋在这个地方\n等待被发现',
              onTap: () => onChanged(DeliveryMode.stay),
            ),
          ),
          const SizedBox(width: KazeSpacing.sm),
          Expanded(
            child: _DeliveryCard(
              selected: mode == DeliveryMode.drift,
              icon: Icons.air,
              title: '投递出去',
              description: '随机寄给\n一个陌生人',
              onTap: () => onChanged(DeliveryMode.drift),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 选中 = 墨蓝深底暖白字（两卡同款）；未选中 = 纸面
    final foreground = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    final secondaryText = selected
        ? theme.colorScheme.onPrimary.withValues(alpha: 0.78)
        : KazeColors.inkFaint;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        // 画布纵向 padding 14；取刻度 sm(8) 留足两行描述的余量
        padding: const EdgeInsets.symmetric(horizontal: KazeSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(KazeWriteDims.deliveryCardRadius),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? foreground : theme.colorScheme.secondary,
                ),
                const SizedBox(width: KazeSpacing.xs + 2),
                // 画布 14 Medium；信息层令牌最近档 titleMedium(16 w500)，
                // 字号偏差记录于此
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 14,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KazeSpacing.xs + 2),
            // 画布 11/16 淡墨；同上偏差记录
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                height: 1.45,
                color: secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
