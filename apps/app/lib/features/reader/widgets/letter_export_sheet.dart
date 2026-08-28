/// 导出结果预览 sheet — 长图预览 + 「保存到相册 / 分享给朋友」。
///
/// 出口动作经 [LetterExportSheet.onSave]/[onShare] 注入（默认实现接
/// Gal / share_plus），测试与未来替换出口都不用动 UI。保存成功关
/// sheet 并 toast；分享拉起系统面板后原样返回。
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';
import 'package:share_plus/share_plus.dart';

/// 弹出导出预览 sheet
Future<void> showLetterExportSheet(
  BuildContext context, {
  required Uint8List png,
}) {
  return showNatsuSheet(
    context: context,
    title: const Text('信已装成图'),
    child: LetterExportSheet(png: png),
  );
}

class LetterExportSheet extends StatefulWidget {
  const LetterExportSheet({
    super.key,
    required this.png,
    this.onSave,
    this.onShare,
  });

  final Uint8List png;

  /// 保存到相册（默认 [saveToGallery]）；失败抛异常即走失败提示
  final Future<void> Function(Uint8List png)? onSave;

  /// 分享给朋友（默认 [shareLetterPng]）
  final Future<void> Function(Uint8List png)? onShare;

  @override
  State<LetterExportSheet> createState() => _LetterExportSheetState();
}

class _LetterExportSheetState extends State<LetterExportSheet> {
  bool _busy = false;

  Future<void> _run(
    Future<void> Function(Uint8List png) action, {
    required String? successToast,
    required String errorToast,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(widget.png);
      if (!mounted) return;
      // toast 先于 pop：toast 在 rootOverlay 自捕获，sheet 的 context
      // pop 后就失效了
      if (successToast != null) showNatsuToast(context, successToast);
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      showNatsuToast(context, errorToast);
      setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(
    widget.onSave ?? saveToGallery,
    successToast: '已存入相册',
    errorToast: '没能存入相册，检查相册权限后再试试',
  );

  Future<void> _share() => _run(
    widget.onShare ?? shareLetterPng,
    successToast: null,
    errorToast: '没能拉起分享，稍后再试试',
  );

  @override
  Widget build(BuildContext context) {
    // 预览区随屏高自适应（矮屏收一收，别把动作区挤出弹层）
    final previewMaxH = math.min(
      420.0,
      MediaQuery.sizeOf(context).height * 0.45,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 长图预览：限高可滚，发丝线圈住天空色不至于融进纸白 sheet
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: previewMaxH),
          child: SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(NatsuRadius.card),
                border: Border.all(color: NatsuColors.paperEdge),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(NatsuRadius.card),
                child: Image.memory(
                  widget.png,
                  fit: BoxFit.fitWidth,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: NatsuSpacing.md),
        NatsuButton(
          variant: NatsuButtonVariant.primary,
          onPressed: _busy ? null : _save,
          child: const Text('保存到相册'),
        ),
        const SizedBox(height: NatsuSpacing.sm),
        NatsuButton(
          variant: NatsuButtonVariant.secondary,
          onPressed: _busy ? null : _share,
          child: const Text('分享给朋友'),
        ),
      ],
    );
  }
}

/// 默认保存：请求相册「仅添加」权限后写入「风信」相册。
/// 权限被拒 / 写入失败都抛异常，由 sheet 统一走失败提示。
Future<void> saveToGallery(Uint8List png) async {
  if (!await Gal.hasAccess(toAlbum: true) &&
      !await Gal.requestAccess(toAlbum: true)) {
    throw StateError('gallery access denied');
  }
  // gal 会按字节内容自动补 .png 扩展名，name 里不带后缀避免 .png.png
  await Gal.putImageBytes(
    png,
    album: '风信',
    name:
        'kaze_no_tayori_letter_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}',
  );
}

/// 默认分享：内存字节直接进系统分享面板，不落盘临时文件
Future<void> shareLetterPng(Uint8List png) {
  final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  return SharePlus.instance.share(
    ShareParams(
      title: '风信 · 一封信',
      files: [
        XFile.fromData(
          png,
          mimeType: 'image/png',
          name: 'kaze_no_tayori_letter_$stamp.png',
        ),
      ],
    ),
  );
}
