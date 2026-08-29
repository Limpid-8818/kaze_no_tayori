/// 主题构造（管理端工作台）。
///
/// **这是本工程唯一允许 import `natsu_no_tegami` 令牌的地方**（纪律与
/// apps/app 的 theme.dart 相同）。管理端是中性密集工作台风格：白底、
/// 纸面卡、小圆角——只共享 token 层（色板/字体/圆角），不复用叙事组件；
/// 唯一的例外是审核预览的信件渲染组件（LetterReading），它经
/// `shared/letter_preview_panel.dart` 显式取用，因为「所见即读者所见」
/// 是审核的核心诉求（docs/ADMIN_CONSOLE.md §2）。
library;

import 'package:flutter/material.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';

import '../data/models/enums.dart';

abstract final class AdminTheme {
  static ThemeData light() {
    final scheme = ColorScheme.light(
      primary: NatsuColors.inkBlue,
      onPrimary: NatsuColors.paperWhite,
      secondary: NatsuColors.skyBlue,
      onSecondary: NatsuColors.paperWhite,
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
      // 工作台：白底（区别于匿名端的天空环境层）
      scaffoldBackgroundColor: const Color(0xFFF7F6F2),
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
      dividerTheme: const DividerThemeData(
        color: NatsuColors.paperEdge,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: NatsuColors.paperWhite,
        isDense: true,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(NatsuRadius.card)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NatsuColors.inkBlue,
          side: const BorderSide(color: NatsuColors.paperEdge),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(NatsuRadius.card)),
          ),
        ),
      ),
      splashFactory: InkRipple.splashFactory,
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: NatsuColors.paperWhite,
        indicatorColor: NatsuColors.envelope,
        selectedIconTheme: const IconThemeData(color: NatsuColors.inkBlue),
        unselectedIconTheme: const IconThemeData(color: NatsuColors.inkSoft),
        selectedLabelTextStyle: const TextStyle(
          color: NatsuColors.inkBlue,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(color: NatsuColors.inkSoft),
      ),
    );
  }

  /// 状态语义色（信件/举报/反馈徽标共用）— 源自令牌层。
  static Color statusColor(LetterStatus status) => switch (status) {
    LetterStatus.pending => NatsuColors.statusWarning,
    LetterStatus.public => NatsuColors.statusSuccess,
    LetterStatus.rejected => NatsuColors.error,
    LetterStatus.takenDown => NatsuColors.inkFaint,
  };

  /// 状态中文标签。
  static String statusLabel(LetterStatus status) => switch (status) {
    LetterStatus.pending => '待审核',
    LetterStatus.public => '公开',
    LetterStatus.rejected => '已驳回',
    LetterStatus.takenDown => '已下架',
  };
}
