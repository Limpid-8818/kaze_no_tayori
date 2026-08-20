/// 主题构造。
///
/// **这是唯一允许 import `natsu_no_tegami` 的地方**（见根 CLAUDE.md §7）。
/// feature 代码一律走 `Theme.of(context)`，不写字面量颜色/字号/间距——
/// 这样上游设计系统拷入后，换主题不需要改任何 feature。
///
/// 当前 `KazeTempTheme` 是**临时主题**：色值抄自 docs/natsu-tokens-v2.json，
/// 用系统字体，不做手写体、纸感、倾斜。上游组件库成形拷入后整体删除，
/// 改为用真实令牌构造 ThemeData（见 packages/natsu_no_tegami/COPY_IN.md）。
library;

import 'package:flutter/material.dart';

/// 临时色板。取自「夏の手紙 v2」令牌，仅取本阶段用得到的那几支。
abstract final class _T {
  static const skyTop = Color(0xFFC9E2F2); // 天空顶 · 清透天青
  static const skyHorizon = Color(0xFFFAF8F1); // 地平线 · 暖白
  static const paperWhite = Color(0xFFFFFFFF); // 白纸 · 内容表面
  static const envelope = Color(0xFFFCF9F2); // 封筒 · 引用底
  static const paperEdge = Color(0xFFE8E4DA); // 纸缘 · 描边
  static const inkBlue = Color(0xFF2B3A55); // 墨蓝 · 正文/主按钮
  static const inkSoft = Color(0xFF55617D); // 次级墨 · 说明文字
  static const inkFaint = Color(0xFF8A93A8); // 淡墨 · caption
  static const skyBlue = Color(0xFF1F6FA8); // 夏空蓝 · 交互色
  static const coralStamp = Color(0xFFE07A5F); // 珊瑚 · 邮戳/邮票（配给制）
  static const error = Color(0xFFC0392B);
  static const onInk = Color(0xFFFFFFFF);
}

abstract final class KazeTempTheme {
  /// 夏日天空渐变。环境是天空，纸只在「信」的时候出现。
  static const skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_T.skyTop, _T.skyHorizon],
    stops: [0.0, 0.72],
  );

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: _T.inkBlue,
      onPrimary: _T.onInk,
      secondary: _T.skyBlue,
      onSecondary: _T.onInk,
      // 珊瑚色是配给制：只用于邮戳/邮票/旅行标记，不承载正文
      tertiary: _T.coralStamp,
      onTertiary: _T.onInk,
      surface: _T.paperWhite,
      onSurface: _T.inkBlue,
      surfaceContainerLow: _T.envelope,
      outline: _T.paperEdge,
      error: _T.error,
      onError: _T.onInk,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _T.skyHorizon,
      // 无阴影：层次靠纸感与留白，不靠 elevation
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: _T.inkBlue,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: _T.paperWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          side: BorderSide(color: _T.paperEdge),
        ),
      ),
      textTheme: _textTheme,
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: _T.paperWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
          borderSide: BorderSide(color: _T.paperEdge),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
          borderSide: BorderSide(color: _T.paperEdge),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
          borderSide: BorderSide(color: _T.skyBlue, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _T.inkBlue,
          foregroundColor: _T.onInk,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _T.paperEdge,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static const _textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 48, height: 1.15, color: _T.inkBlue),
    headlineMedium: TextStyle(fontSize: 32, height: 1.25, color: _T.inkBlue),
    titleLarge: TextStyle(fontSize: 22, height: 1.35, color: _T.inkBlue),
    bodyLarge: TextStyle(fontSize: 16, height: 1.7, color: _T.inkBlue),
    bodyMedium: TextStyle(fontSize: 16, height: 1.7, color: _T.inkSoft),
    labelLarge: TextStyle(fontSize: 15, height: 1.2, color: _T.inkBlue),
    bodySmall: TextStyle(fontSize: 13, height: 1.5, color: _T.inkFaint),
  );
}
