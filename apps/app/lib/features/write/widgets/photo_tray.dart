/// 图片托盘 —— 朋友圈式：按照片**实际所在信内位置**排序的缩略图行，
/// 尾随一个灰色加号格（已满三张时消失）。加号选图即插入当前光标处
/// （见 WriteController.addPhotosAtCursor），点缩略图弹预览/移除弹层。
///
/// 画布 Screen/Write 没有这个元素——交互补件，视觉沿用设计语言
/// （纸面卡 + 发丝线 + 淡墨图标）。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../../app/theme.dart';
import '../../../core/env.dart';
import '../write_controller.dart';

class PhotoTray extends StatelessWidget {
  const PhotoTray({
    required this.photos,
    required this.onAdd,
    required this.onOpen,
    super.key,
  });

  final List<WritePhotoBlock> photos;
  final VoidCallback onAdd;
  final void Function(int photoBlockId) onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: KazeWriteDims.trayThumb,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final photo in photos)
            Padding(
              padding: const EdgeInsets.only(right: KazeSpacing.sm),
              child: _TrayThumb(photo: photo, onTap: () => onOpen(photo.id)),
            ),
          if (photos.length < Env.letterMaxImages) _AddTile(onTap: onAdd),
        ],
      ),
    );
  }
}

class _TrayThumb extends StatelessWidget {
  const _TrayThumb({required this.photo, required this.onTap});

  final WritePhotoBlock photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = KazeWriteDims.trayThumb;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(KazeRadius.card),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(KazeRadius.card),
              child: Image.file(File(photo.localPath), fit: BoxFit.cover),
            ),
          ),
          switch (photo.phase) {
            PhotoUploadPhase.pending ||
            PhotoUploadPhase.uploading => Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(KazeRadius.card),
                child: ColoredBox(
                  color: theme.colorScheme.surface.withValues(alpha: 0.55),
                  child: const Center(
                    child: NatsuSpinner(size: NatsuSpinnerSize.sm),
                  ),
                ),
              ),
            ),
            PhotoUploadPhase.failed => Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(KazeRadius.card),
                child: ColoredBox(
                  color: KazeColors.scrim,
                  child: Icon(
                    Icons.cloud_off_outlined,
                    size: size / 3,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            PhotoUploadPhase.uploaded => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }
}

/// 灰色加号格：暖白底 + 发丝线 + 淡墨加号——「还有位置，继续夹照片」。
class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = KazeWriteDims.trayThumb;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(KazeRadius.card),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Icon(Icons.add, size: size / 3, color: KazeColors.inkFaint),
      ),
    );
  }
}
