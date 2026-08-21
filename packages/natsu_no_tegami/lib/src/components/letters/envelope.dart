import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../tokens/natsu_tokens.dart';
import '../natsu_seal.dart';
import 'postmark.dart';
import 'scaled_design.dart';
import 'skins/letter_skin.dart';
import 'skins/natsu_skins.dart';
import 'stamp_piece.dart';
import 'vertical_handwriting.dart';

/// 夏の手紙 v2 · 竖形封筒 — 和式纵形，信的封面
///
/// **同一设计，等比呈现**：封面全部要素按基准宽 [baseWidth] 固定设计，
/// 整体经 `Transform.scale` 缩放到目标 [width]——封筒不管在哪里显示、
/// 显示多大，都是同一份设计的等比缩放：邮票、邮戳、宛名、刻印的相对
/// 位置不变，**各素材内部的比例也不变**（邮戳的环与文字、邮票的锯齿
/// 边与面值、竖排字的字距——全部随整体缩放），视觉上没有任何改变。
///
/// 竖比例 1:2.2（[width] × 2.2）。筒面 envelope 暖白纯色（光的信息
/// 传递由环境天空承担，纸面不画光）。
///
/// 封面要素（基准宽 200 下的设计值，全部贴/盖在筒面上——承托纪律）：
/// - 邮票：右上，40×50（真实封筒上邮票是小角贴）
/// - 邮戳：左上，88px 标准章等比缩放呈现（视觉直径 72）
/// - 宛名：竖排手写 [addressee]，写信人自填；**null = 封面洁净**
/// - 刻印封缄：右下摺垂れ位置
///
/// 皮肤 [skin] 只消费邮票与邮戳图案两槽（decor 属于信纸，不贴封筒）。
/// 开信动画不是组件库的职责——App 阶段由路由编排。
class Envelope extends StatelessWidget {
  const Envelope({
    super.key,
    required this.seedId,
    this.skin = const LetterSkin(),
    this.addressee,
    required this.place,
    required this.date,
    this.weather,
    this.sealCharacter = '夏',
    this.width = 200,
    this.tilt,
  });

  /// 种子 ID（倾斜的确定性来源）
  final String seedId;

  /// 皮肤搭配（邮票/邮戳图案两槽挂载）
  final LetterSkin skin;

  /// 宛名（竖排手写）；null = 封面洁净
  final String? addressee;

  /// 邮戳内容（地点/日期/天气——信的语境锚点）
  final String place;
  final String date;
  final String? weather;

  /// 封缄刻印字符
  final String sealCharacter;

  /// 封筒显示宽（高 = width × 2.2）；内部布局恒定，整体等比缩放至此
  final double width;

  /// 覆盖种子倾斜（度）；null = 种子派生的轻倾斜
  final double? tilt;

  /// 竖形封筒比例（宽:高 = 1:2.2）
  static const double aspectRatio = 2.2;

  /// 基准设计宽 — 封面所有要素的尺寸与位置以此为参照设计；
  /// 目标 width 只经整体 Transform.scale 映射，不改任何内部值
  static const double baseWidth = 200;

  static const double baseHeight = baseWidth * aspectRatio;

  /// 邮票宽（基准值；票面比例 0.8）
  static const double _stampWidth = 40;

  /// 邮戳视觉直径（88 基准章的呈现尺寸——章的内部设计不缩改，
  /// 只等比呈现）
  static const double _postmarkVisual = 72;

  /// 刻印尺寸（基准值）
  static const double _sealSize = 32;

  @override
  Widget build(BuildContext context) {
    final angle =
        (tilt ?? NatsuImperfection.tiltOf(seedId)) * 0.75 * math.pi / 180;

    return Transform.rotate(
      angle: angle,
      // 同一设计等比呈现：基准 200×440 坐标系 + 绘制期整体缩放
      // （ScaledDesign 是本模式的通用封装——Envelope 是它的第一个用户）
      child: ScaledDesign(
        baseWidth: baseWidth,
        baseHeight: baseHeight,
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: NatsuColors.envelope,
            borderRadius: BorderRadius.circular(NatsuRadius.letter),
            border: NatsuBorders.hairline,
            boxShadow: NatsuShadows.letterResting,
          ),
          // 筒面保持纯色——光的信息传递由环境天空（天气光联动）承担
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 邮票：右上部（和式封筒的邮票位）——比例锁 0.8
              Positioned(
                right: 14,
                top: 44,
                child: StampPiece(
                  seedId: '$seedId/stamp',
                  motive: skin.stampId == null
                      ? null
                      : SkinMotive(skin.stampId!),
                  width: _stampWidth,
                ),
              ),
              // 邮戳：左上部——88 基准章等比呈现（size 只定大小）
              Positioned(
                left: 14,
                top: 44,
                child: Postmark(
                  place: place,
                  date: date,
                  weather: weather,
                  seedId: '$seedId/postmark',
                  size: _postmarkVisual,
                  emblem: skin.postmarkEmblemId == null
                      ? null
                      : SkinMotive(skin.postmarkEmblemId!),
                ),
              ),
              // 宛名：竖排，封面中下部（null = 整块不渲染，封面洁净）
              if (addressee != null)
                Positioned(
                  right: 44,
                  bottom: 70,
                  child: VerticalHandwriting(text: addressee!, maxHeight: 190),
                ),
              // 刻印封缄：右下摺垂れ位置
              Positioned(
                right: 24,
                bottom: 22,
                child: NatsuSeal(character: sealCharacter, size: _sealSize),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
