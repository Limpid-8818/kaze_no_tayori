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
    );
  }

  /// 信息层字体映射。正文/标题用 NotoSans 系；手写体（hwBody/hwNote/…）
  /// 是信件内容物的温度层，由 `letters/` 组件直接引用令牌，不进全局 TextTheme。
  /// 次级正文直接用上游现成的 bodySecondary 令牌（同为 copyWith 产物）。
  static const _textTheme = TextTheme(
    displayLarge: NatsuTypography.display,
    headlineMedium: NatsuTypography.heading,
    titleLarge: NatsuTypography.subheading,
    bodyLarge: NatsuTypography.body,
    bodyMedium: NatsuTypography.bodySecondary,
    labelLarge: NatsuTypography.button,
    bodySmall: NatsuTypography.caption,
  );
}
