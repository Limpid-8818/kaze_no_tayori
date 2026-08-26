/// 主题构造。
///
/// **这是唯一允许 import `natsu_no_tegami` 令牌的地方**（见根 CLAUDE.md §7）。
/// feature 代码一律走 `Theme.of(context)`，不写字面量颜色/字号/间距--
/// 换主题不需要改任何 feature 代码。
///
/// 令牌来自上游设计系统（`NatsuColors` / `NatsuTypography` 等 const 静态类），
/// 映射成 Material `ColorScheme` + `TextTheme`：
/// - 环境层（天空渐变）作 scaffold 背景，纸面层作 surface
/// - 墨蓝系承载正文与主按钮，夏空蓝是交互色
/// - 珊瑚是配给制：只映射到 tertiary（邮戳/邮票/旅行标记专用），feature 不拿它画正文
/// - 手写体（hw*）不进 TextTheme--那是信件内容物的字体，由 `letters/` 组件自带
library;

import 'package:flutter/material.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

abstract final class KazeTheme {
  /// 夏日天空渐变。环境是天空，纸只在「信」的时候出现。
  /// （读信时随信携带的天气×时段切换，见 NatsuWeatherLight；此为默认昼·晴。）
  static const skyGradient = NatsuColors.skyGradient;

  static ThemeData light() {
    final scheme = ColorScheme.light(
      primary: NatsuColors.inkBlue,
      onPrimary: NatsuColors.paperWhite,
      secondary: NatsuColors.skyBlue,
      onSecondary: NatsuColors.paperWhite,
      // 珊瑚色是配给制：只用于邮戳/邮票/旅行标记，不承载正文
      tertiary: NatsuColors.coralStamp,
      onTertiary: NatsuColors.paperWhite,
      surface: NatsuColors.paperWhite,
      onSurface: NatsuColors.inkBlue,
      onSurfaceVariant: NatsuColors.inkSoft,
      surfaceContainerLow: NatsuColors.envelope,
      outline: NatsuColors.paperEdge,
      error: NatsuColors.error,
      onError: NatsuColors.paperWhite,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: NatsuColors.skyHorizon,
      // 无阴影：层次靠纸感与留白，不靠 elevation
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: NatsuColors.inkBlue,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: NatsuColors.paperWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(NatsuRadius.card)),
          side: BorderSide(color: NatsuColors.paperEdge),
        ),
      ),
      textTheme: _textTheme,
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: NatsuColors.paperWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(NatsuRadius.card)),
          borderSide: BorderSide(color: NatsuColors.paperEdge),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(NatsuRadius.card)),
          borderSide: BorderSide(color: NatsuColors.paperEdge),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(NatsuRadius.card)),
          borderSide: BorderSide(color: NatsuColors.skyBlue, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NatsuColors.inkBlue,
          foregroundColor: NatsuColors.paperWhite,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(NatsuRadius.card)),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: NatsuColors.paperEdge,
        thickness: 1,
        space: 1,
      ),
      // 触摸反馈不使用完整圆形：InkWell/IconButton 等波纹统一方形小圆角
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(NatsuRadius.card)),
          ),
        ),
      ),
    );
  }

  /// 信息层字体映射。正文/标题用 NotoSans 系；手写体（hwBody/hwNote/…）
  /// 是信件内容物的温度层，由 `letters/` 组件直接引用令牌，不进全局 TextTheme。
  /// 次级正文直接用上游现成的 bodySecondary 令牌（同为 copyWith 产物）。
  // final（非 const）：headlineSmall 需 copyWith 派生
  static final _textTheme = TextTheme(
    displayLarge: NatsuTypography.display,
    headlineMedium: NatsuTypography.heading,
    // 问候语一档：画布 26pt SemiBold，信息层令牌无此档，
    // 自 heading(32 Bold) 派生（映射层记录偏差，feature 仍走 TextTheme）
    headlineSmall: NatsuTypography.heading.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w600,
    ),
    // 卡片标题/品牌字一档：画布 20-22pt SemiBold，信息层令牌无此档，
    // 取 subheading(22) 最近档（令牌纪律优先，字号偏差记录于此）
    titleLarge: NatsuTypography.subheading,
    titleMedium: NatsuTypography.bodyStrong,
    bodyLarge: NatsuTypography.body,
    bodyMedium: NatsuTypography.bodySecondary,
    labelLarge: NatsuTypography.button,
    bodySmall: NatsuTypography.caption,
    // 环境行/抽屉分组标签一档：meta(13) 与 label(13) 同尺寸，
    // meta 是「地点·时间·天气」邮戳式元数据的专用令牌
    labelMedium: NatsuTypography.meta,
    labelSmall: NatsuTypography.label,
  );
}

/// 间距速记 — feature 不许 import 令牌、不许写字面量间距，经此中转。
/// 值源自 [NatsuSpacing]（组件内紧凑刻度）。
abstract final class KazeSpacing {
  static const double xs = NatsuSpacing.xs;
  static const double sm = NatsuSpacing.sm;
  static const double md = NatsuSpacing.md;
  static const double lg = NatsuSpacing.lg;
  static const double xl = NatsuSpacing.xl;
}

/// 圆角速记 — 值源自 [NatsuRadius]。
abstract final class KazeRadius {
  /// 卡片·按钮·输入框
  static const double card = NatsuRadius.card;
}

/// 少量无 ColorScheme 槽位的具名色 — 全部源自令牌层，feature 经此类取用。
abstract final class KazeColors {
  /// 次级墨 — 说明文字（ColorScheme.onSurfaceVariant 同源，图标等场景用）
  static const Color inkSoft = NatsuColors.inkSoft;

  /// 淡墨 — 非关键小字（卡片描述/抽屉底注）
  static const Color inkFaint = NatsuColors.inkFaint;

  /// 叶绿 — 自然/旅行语义（地点 pin）
  static const Color leaf = NatsuColors.leaf;

  /// 图标井底色 — skyTop 35% 透明（画布 Home 入口卡 48×48 IconBg）
  static const Color iconWell = Color(0x59C9E2F2);

  /// 暖白纸面底 — 入口卡等浅色表面（信封/禁用底同源）
  static const Color envelope = NatsuColors.envelope;
}

/// Home 画布（夏の手紙 v2 · Screen/Home）的结构尺寸 — 非间距刻度，
/// 集中于此避免 feature 散落魔法数。
abstract final class KazeHomeDims {
  /// AppBar 工具条高
  static const double appBarH = 52;

  /// 入口卡高
  static const double cardH = 88;

  /// 图标井（48×48）
  static const double iconWell = 48;

  /// 抽屉宽
  static const double drawerW = 300;

  /// 抽屉导航行高
  static const double drawerRowH = 52;

  /// 抽屉导航图标（20×20）
  static const double drawerIcon = 20;

  /// 入口卡图标（24×24）
  static const double entryIcon = 24;

  /// 环境行小圆点直径
  static const double envDot = 3;
}

/// About 画布（夏の手紙 v2 · Screen/About）的结构尺寸 — 非间距刻度，
/// 集中于此避免 feature 散落魔法数。
abstract final class KazeAboutDims {
  /// App Logo（88×88）
  static const double logo = 88;

  /// App Logo 圆角
  static const double logoRadius = 20;

  /// 团队 Logo（85×32）
  static const double teamLogoW = 85;
  static const double teamLogoH = 32;

  /// 灵感来源专辑封面（48×48）
  static const double album = 48;

  /// 专辑封面圆角
  static const double albumRadius = 4;
}
