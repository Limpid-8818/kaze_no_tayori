import 'package:flutter/painting.dart';

import 'natsu_colors.dart';

/// 夏の手紙 v2 · 字体族令牌 — 三角色（中文优先回落链）
///
/// 结构层现代（UI sans）、内容物有人的温度（手写 hw）、文学引用留一点
/// 铅字书卷气（quote serif）：
/// - ui = NotoSansSC → NotoSansJP（回退承接假名）
/// - hw = LXGWWenKai → KleeOne（信正文/手记/邮戳手写）
/// - quote = NotoSerifSC → NotoSerifJP（**仅** quoteSerif 一个样式）
///
/// 回落方向纪律（中文优先）：日文字体覆盖大部分常用汉字且为日式新字体
/// 字形——JP 排前面时中文渲染成日文字形。所有族 SC 主、JP 回退。
abstract final class NatsuFontFamilies {
  /// Flutter 对依赖包字体使用 `packages/<package>/` 命名空间。
  static const String packageName = 'natsu_no_tegami';

  // ---- UI（结构层）-----------------------------------------------------------
  static const String ui = 'NotoSansSC';
  static const List<String> uiFallback = ['NotoSansJP'];

  static const String uiEn = 'Inter';

  /// 欧文样式的 CJK 续接链 — Inter 无 CJK 字形，标签/caption 常混排
  /// 中日文（如「夜の電車」），按中文优先纪律 SC 主、JP 回退。
  static const List<String> uiEnCjkFallback = ['NotoSansSC', 'NotoSansJP'];

  /// 等宽 — 展示页色值/代码用
  static const String mono = 'RobotoMono';

  // ---- 手写（内容物的声音）----------------------------------------------------
  static const String hw = 'LXGWWenKai';
  static const List<String> hwFallback = ['KleeOne'];

  // ---- 引用（铅字，仅一处）----------------------------------------------------
  static const String quote = 'NotoSerifSC';
  static const List<String> quoteFallback = ['NotoSerifJP'];

  // ---- 品牌刻印 ---------------------------------------------------------------
  static const String seal = 'MaShanZheng';
  static const List<String> sealFallback = ['ZenKurenaido'];
}

/// 夏の手紙 v2 · 文字样式令牌
///
/// 尺寸体系沿用 v1（来自 yorushika-design-tokens.json），角色与颜色换 v2：
/// 标题从明朝改 sans（结构层克制现代的关键一刀），衬线只活在 quoteSerif。
abstract final class NatsuTypography {
  // ---- UI 层 ---------------------------------------------------------------
  /// Display 48 — 大标题（sans SemiBold）
  static const TextStyle display = TextStyle(
    fontFamily: NatsuFontFamilies.ui,
    fontFamilyFallback: NatsuFontFamilies.uiFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w600,
    fontSize: 48,
    height: 60 / 48,
    color: NatsuColors.inkBlue,
  );

  /// Heading 32 — 章节标题（sans Bold）
  static const TextStyle heading = TextStyle(
    fontFamily: NatsuFontFamilies.ui,
    fontFamilyFallback: NatsuFontFamilies.uiFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w700,
    fontSize: 32,
    height: 42 / 32,
    color: NatsuColors.inkBlue,
  );

  /// Subheading 22 — 欧文副标题（Inter；CJK 经回退链续接）
  static const TextStyle subheading = TextStyle(
    fontFamily: NatsuFontFamilies.uiEn,
    fontFamilyFallback: NatsuFontFamilies.uiEnCjkFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w400,
    fontSize: 22,
    height: 32 / 22,
    color: NatsuColors.inkBlue,
  );

  /// Body 16 — 正文（1.75 行距）
  static const TextStyle body = TextStyle(
    fontFamily: NatsuFontFamilies.ui,
    fontFamilyFallback: NatsuFontFamilies.uiFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 28 / 16,
    color: NatsuColors.inkBlue,
  );

  /// Body Strong
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: NatsuFontFamilies.ui,
    fontFamilyFallback: NatsuFontFamilies.uiFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 28 / 16,
    color: NatsuColors.inkBlue,
  );

  /// 副文本 — 说明文字
  static const TextStyle bodySecondary = TextStyle(
    fontFamily: NatsuFontFamilies.ui,
    fontFamilyFallback: NatsuFontFamilies.uiFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 28 / 16,
    color: NatsuColors.inkSoft,
  );

  /// Caption 13 — 小字（Inter；CJK 经回退链续接）
  static const TextStyle caption = TextStyle(
    fontFamily: NatsuFontFamilies.uiEn,
    fontFamilyFallback: NatsuFontFamilies.uiEnCjkFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 20 / 13,
    color: NatsuColors.inkFaint,
  );

  /// Kicker — 章节眉标（Inter + 2px 字距；CJK 经回退链续接）
  static const TextStyle kicker = TextStyle(
    fontFamily: NatsuFontFamilies.uiEn,
    fontFamilyFallback: NatsuFontFamilies.uiEnCjkFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 20 / 13,
    letterSpacing: 2,
    color: NatsuColors.inkSoft,
  );

  /// Label — 分组标签（Inter + 1.5px 字距；CJK 经回退链续接）
  static const TextStyle label = TextStyle(
    fontFamily: NatsuFontFamilies.uiEn,
    fontFamilyFallback: NatsuFontFamilies.uiEnCjkFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 20 / 13,
    letterSpacing: 1.5,
    color: NatsuColors.inkSoft,
  );

  /// 按钮文字 — w600：15px 小字在深底上需要更实的字重
  static const TextStyle button = TextStyle(
    fontFamily: NatsuFontFamilies.ui,
    fontFamilyFallback: NatsuFontFamilies.uiFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 22 / 15,
    color: NatsuColors.inkBlue,
  );

  /// MetaLine — 邮戳式元数据（地点·时间·天气；CJK 经回退链续接）
  static const TextStyle meta = TextStyle(
    fontFamily: NatsuFontFamilies.uiEn,
    fontFamilyFallback: NatsuFontFamilies.uiEnCjkFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 20 / 13,
    letterSpacing: 1.2,
    color: NatsuColors.inkSoft,
  );

  // ---- 手写层（内容物）--------------------------------------------------------
  /// 手写信标题 36 — LXGW WenKai
  static const TextStyle hwLetter = TextStyle(
    fontFamily: NatsuFontFamilies.hw,
    fontFamilyFallback: NatsuFontFamilies.hwFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w400,
    fontSize: 36,
    height: 54 / 36,
    color: NatsuColors.inkBlue,
  );

  /// 手写信正文 20 — LXGW WenKai（信件阅读主体）
  static const TextStyle hwBody = TextStyle(
    fontFamily: NatsuFontFamilies.hw,
    fontFamilyFallback: NatsuFontFamilies.hwFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w400,
    fontSize: 20,
    height: 38 / 20,
    color: NatsuColors.inkBlue,
  );

  /// 手写信宛名/署名 28 — LXGW WenKai
  static const TextStyle hwAddress = TextStyle(
    fontFamily: NatsuFontFamilies.hw,
    fontFamilyFallback: NatsuFontFamilies.hwFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w400,
    fontSize: 28,
    height: 44 / 28,
    color: NatsuColors.inkBlue,
  );

  /// 竖排手写的字间额外间距 — 竖排（单字 Column）里 TextStyle 的行高
  /// 不参与字距，由它补足视觉密度（hwAddress 28px 字号的约 0.29 倍，
  /// 接近原 44 行高的疏密）
  static const double verticalAddressGap = 8.0;

  /// 追筆 24 — 与宛名/署名同字体栈，灰而退后（层级靠字号与灰色，不换笔）
  static const TextStyle hwPostscript = TextStyle(
    fontFamily: NatsuFontFamilies.hw,
    fontFamilyFallback: NatsuFontFamilies.hwFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w400,
    fontSize: 24,
    height: 38 / 24,
    color: NatsuColors.inkSoft,
  );

  /// 手写小注 — 照片手记/邮戳手写部分
  static const TextStyle hwNote = TextStyle(
    fontFamily: NatsuFontFamilies.hw,
    fontFamilyFallback: NatsuFontFamilies.hwFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 26 / 16,
    color: NatsuColors.inkSoft,
  );

  /// 品牌刻印 — Ma Shan Zheng（珊瑚）
  static const TextStyle hwSeal = TextStyle(
    fontFamily: NatsuFontFamilies.seal,
    fontFamilyFallback: NatsuFontFamilies.sealFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w400,
    fontSize: 56,
    height: 72 / 56,
    color: NatsuColors.coralStamp,
  );

  // ---- 引用层（铅字，仅一处）--------------------------------------------------
  /// 引用 — 歌词引用 / AI 短诗（Noto Serif SC，中文不斜、靠灰度退后）。
  /// 系统中唯一的衬线样式：纸上的铅字 vs 手写的对比，本就是书信文化的一部分。
  static const TextStyle quoteSerif = TextStyle(
    fontFamily: NatsuFontFamilies.quote,
    fontFamilyFallback: NatsuFontFamilies.quoteFallback,
    package: NatsuFontFamilies.packageName,
    fontWeight: FontWeight.w400,
    fontSize: 18,
    height: 32 / 18,
    color: NatsuColors.inkSoft,
  );
}
