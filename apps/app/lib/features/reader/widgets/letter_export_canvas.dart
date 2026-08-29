/// 信件导出画布 — 把一封信构图成一张可分享长图。
///
/// 构图口径与读信页同源：整幅背景 = [skyOfLetter] 的信件天色渐变，
/// 信纸本体直接复用设计系统 [LetterReading]（非重绘复刻）——信纸样式
/// 演进时导出图自动跟随，所见即所导。纸浮在天空里，上下留白把光留给
/// 环境；下留白区右下角压 app logo + 「风信」水印（全部 12 档天色的
/// 底部留白均为浅色——夜档是月光调冷银蓝而非暗色，固定墨蓝即可读）。
///
/// 匿名性（PRD §8.1）：入参与 LetterReading 同口径，不含任何作者信息。
library;

import 'package:flutter/material.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../../../app/theme.dart';
import '../letter_view.dart';

class LetterExportCanvas extends StatelessWidget {
  /// 水印 logo 资产路径。导出管线据此预热图片缓存（见 letter_exporter
  /// 的照片预热注释——首次导出若不预热，首帧里 logo 是空白的）。
  static const String logoAsset = 'assets/images/app_logo.png';

  const LetterExportCanvas({
    super.key,
    required this.blocks,
    required this.photoResolver,
    this.seedId,
    this.place,
    this.time,
    this.dayPeriod,
    this.weather,
    this.signature,
    this.skyGradient = KazeSky.defaultGradient,
    this.watermark = true,
  });

  final List<LetterBlock> blocks;

  /// 图片引用 → ImageProvider（导出走缓存网络图，测试注入 MemoryImage）
  final ImageProvider Function(String ref) photoResolver;

  final String? seedId;
  final String? place;
  final String? time;
  final String? dayPeriod;
  final String? weather;
  final String? signature;

  /// 信件天色（读信页与导出图共用 [skyOfLetter] 的结果）
  final Gradient skyGradient;

  /// 右下角品牌水印；测试构图时可关掉
  final bool watermark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Material.transparency：离屏 Overlay 无 Material 祖先，debug 下 Text
    // 会画出黄双下划线调试标记污染导出图；透明 Material 只补上
    // DefaultTextStyle 环境，不改变任何视觉
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: KazeExportDims.canvasW,
        decoration: BoxDecoration(gradient: skyGradient),
        child: Stack(
          children: [
            // 信纸浮在天空里：上留白开阔、下留白兼作水印区
            Padding(
              padding: const EdgeInsets.only(
                top: KazeExportDims.marginTop,
                bottom: KazeExportDims.marginBottom,
              ),
              child: Center(
                child: LetterReading(
                  blocks: blocks,
                  photoResolver: photoResolver,
                  seedId: seedId,
                  width: KazeExportDims.paperW,
                  place: place,
                  time: time,
                  dayPeriod: dayPeriod,
                  weather: weather,
                  signature: signature,
                ),
              ),
            ),
            if (watermark)
              Positioned(
                right: KazeExportDims.markRight,
                bottom: KazeExportDims.markBottom,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        KazeExportDims.markLogoRadius,
                      ),
                      child: Image.asset(
                        logoAsset,
                        width: KazeExportDims.markLogo,
                        height: KazeExportDims.markLogo,
                      ),
                    ),
                    const SizedBox(width: KazeExportDims.markGap),
                    Text(
                      '风信',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
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
