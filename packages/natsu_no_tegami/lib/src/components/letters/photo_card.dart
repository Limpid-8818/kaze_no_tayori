import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../tokens/natsu_tokens.dart';

/// 夏の手紙 v2 · 照片 — 桌上散落的旅行记忆
///
/// Controlled Imperfection 的代表组件：
/// - 确定性倾斜：[seedId] 派生（同一张照片永远歪同一个角度）
/// - 白边相纸：paperWhite 底 + 10px 边 + 底部留白写手记
/// - 颗粒：`_GrainPainter` 用种子伪随机点画胶片颗粒（相纸介质）
/// - 暖边：左上→右下的 sunlight 低透明渐变（光从左上来）
/// - [mood]（拍摄瞬间）：过曝/逆光/运动模糊三选，默认素——
///   与相纸介质层叠加不替代（颗粒属于相纸，永远最顶）
///
/// 纯 CustomPainter + Flutter 内置滤镜实现——无 shader、无图片资产。
/// 「过曝的光感」由 mood 系统承载，不在介质层烘焙光带。
class PhotoCard extends StatelessWidget {
  const PhotoCard({
    super.key,
    required this.image,
    required this.seedId,
    this.caption,
    this.width = 280,
    this.height = 200,
    this.tilt,
    this.mood = PhotoMood.none,
  });

  final ImageProvider image;

  /// 种子 ID（倾斜/颗粒/光带布局的确定性来源）
  final String seedId;

  /// 照片手记（hw 手写，白边底部）
  final String? caption;

  final double width;

  /// 画面高度（不含白边与手记区）
  final double height;

  /// 覆盖种子倾斜（度）；null = NatsuImperfection.tiltOf(seedId)
  final double? tilt;

  /// 拍摄瞬间 mood（素/过曝/逆光/运动模糊）——写信时选，不默认硬加
  final PhotoMood mood;

  /// 相纸外壳基准宽（viewBox）——白边/圆角/线宽以它为参照等比
  static const double shellBaseWidth = 280;

  @override
  Widget build(BuildContext context) {
    final angle = (tilt ?? NatsuImperfection.tiltOf(seedId)) * math.pi / 180;
    // 相纸外壳等比：白边/圆角/线宽 × k（280 基准）；手记字号固定——
    // 字是内容不是外壳，任意尺寸下保持 hwNote 的阅读层级
    final k = width / shellBaseWidth;

    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        padding: EdgeInsets.fromLTRB(10 * k, 10 * k, 10 * k, 8 * k),
        decoration: BoxDecoration(
          color: NatsuColors.paperWhite,
          borderRadius: BorderRadius.circular(NatsuRadius.letter * k),
          border: Border.all(
            color: NatsuBorders.side.color,
            width: NatsuBorders.side.width * k,
          ),
          boxShadow: NatsuShadows.paperResting,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(k),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 拍摄瞬间 mood：滤镜作用于画面（ColorFiltered/ImageFiltered
                    // 均为 Flutter 内置，零依赖纪律不破）
                    _moodImage(),
                    // mood 光效层（过曝白溢 / 逆光暗角）
                    if (mood == PhotoMood.overexposed)
                      const DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: NatsuPhotoMood.overexposedWash),
                      )
                    else if (mood == PhotoMood.backlit)
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: NatsuPhotoMood.backlitVignetteRadius,
                            focal: Alignment.center,
                            focalRadius: NatsuPhotoMood.backlitVignetteFocal,
                            colors: [
                              NatsuPhotoMood.backlitVignetteCenter,
                              NatsuPhotoMood.backlitVignetteEdge,
                            ],
                            stops: [0.0, 1.0],
                          ),
                        ),
                      ),
                    // 光从左上来的暖边
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0x28FFF6DF), Color(0x00FFF6DF)],
                          stops: [0.0, 0.6],
                        ),
                      ),
                    ),
                    CustomPaint(
                      painter: _GrainPainter(seedId: seedId),
                    ),
                  ],
                ),
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: NatsuSpacing.sm),
              Padding(
                padding: EdgeInsets.only(left: 4 * k, bottom: 4 * k),
                child: Text(caption!, style: NatsuTypography.hwNote),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 画面层 — mood 滤镜包裹（素 = 裸 Image，零回归）
  Widget _moodImage() {
    final img = Image(image: image, fit: BoxFit.cover);
    return switch (mood) {
      PhotoMood.none => img,
      PhotoMood.overexposed => ColorFiltered(
          colorFilter: NatsuPhotoMood.overexposedFilter, child: img),
      PhotoMood.backlit =>
        ColorFiltered(colorFilter: NatsuPhotoMood.backlitFilter, child: img),
      PhotoMood.motion => ImageFiltered(
          imageFilter: NatsuPhotoMood.motionBlur(), child: img),
    };
  }
}

/// 胶片颗粒 — 种子确定性派生的半透明墨蓝点（相纸介质感）
class _GrainPainter extends CustomPainter {
  const _GrainPainter({required this.seedId});

  final String seedId;

  @override
  void paint(Canvas canvas, Size size) {
    // 颗粒：~area/600 个半透明墨蓝 1px 点
    final count = (size.width * size.height / 600).round();
    final paint = Paint().. strokeWidth = 1;
    for (var i = 0; i < count; i++) {
      final dx = NatsuImperfection.seedOf('$seedId/g$i') * size.width;
      final dy = NatsuImperfection.seedOf('$seedId/g${i}y') * size.height;
      final alpha = 8 + (NatsuImperfection.seedOf('$seedId/a$i') * 22).round();
      paint.color = Color.fromARGB(alpha, 43, 58, 85);
      canvas.drawLine(Offset(dx, dy), Offset(dx + 1, dy), paint);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) => oldDelegate.seedId != seedId;
}
