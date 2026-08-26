/// 关于页 — 按画布「夏の手紙 v2」Screen/About 实现。
///
/// 天空渐变上一张信纸卡：品牌（Logo/名/版本）+ 手写致谢 + 团队与灵感出处。
/// 版本号来自 pubspec（构建期注入，运行时经 package_info_plus 读取）。
library;

import 'package:flutter/material.dart';
import 'package:natsu_no_tegami/natsu_no_tegami.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/theme.dart';
import '../../app/widgets/kaze_scaffold.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KazeScaffold(
      title: '关于',
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(KazeRadius.card),
          border: Border.all(color: theme.colorScheme.outline),
          boxShadow: [
            // 画布 LetterCard 的纸影：墨蓝 14%，向下 6 晕开 24
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.14),
              offset: const Offset(0, 6),
              blurRadius: 24,
              spreadRadius: -8,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: const [
              _BrandSection(),
              SizedBox(height: 14),
              Divider(),
              SizedBox(height: 14),
              _TeamBlock(),
              SizedBox(height: 18),
              _InspireBlock(),
              SizedBox(height: 18),
              _DateRow(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 品牌区（居中）：Logo → 应用名 → 欧文名 → 版本 → 手写致谢。
class _BrandSection extends StatelessWidget {
  const _BrandSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 画布欧文小字为 Inter 11 Medium；信息层令牌最近档 caption(13)，
    // 字号偏差记录于此
    final TextStyle eyebrow = theme.textTheme.bodySmall!.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(KazeAboutDims.logoRadius),
          child: Image.asset(
            'assets/images/app_logo.png',
            width: KazeAboutDims.logo,
            height: KazeAboutDims.logo,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 14),
        Text('风信', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('KAZE NO TAYORI', style: eyebrow),
        const SizedBox(height: 4),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.data?.version;
            if (version == null) return const SizedBox.shrink();
            return Text('v$version', style: eyebrow);
          },
        ),
        const SizedBox(height: 14),
        // 内容物层：手写致谢走 hw 令牌（不进 TextTheme，见 theme.dart 头注）
        const Text('谢谢你，愿意把思绪交给风。', style: NatsuTypography.hwNote),
      ],
    );
  }
}

/// 开发团队块：分组标签 + 团队 Logo + 名称/出处。
class _TeamBlock extends StatelessWidget {
  const _TeamBlock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('开发团队', style: theme.textTheme.labelSmall),
        const SizedBox(height: 10),
        Row(
          children: [
            Image.asset(
              'assets/images/team_logo.png',
              width: KazeAboutDims.teamLogoW,
              height: KazeAboutDims.teamLogoH,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ai²', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('大工黑客松 S2 · 制造一点意外', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// 灵感来源块：暖白底小卡承载专辑封面与曲目。
class _InspireBlock extends StatelessWidget {
  const _InspireBlock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('灵感来源', style: theme.textTheme.labelSmall),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            // 信封暖白（surfaceContainerLow ← NatsuColors.envelope）
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(KazeRadius.card),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [_AlbumCover(), SizedBox(width: 12), _InspireText()],
            ),
          ),
        ),
      ],
    );
  }
}

class _AlbumCover extends StatelessWidget {
  const _AlbumCover();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(KazeAboutDims.albumRadius),
      child: Image.asset(
        'assets/images/album_yorushika.png',
        width: KazeAboutDims.album,
        height: KazeAboutDims.album,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _InspireText extends StatelessWidget {
  const _InspireText();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 画布眉标 10 Medium；同 _BrandSection 的偏差记录
    final TextStyle eyebrow = theme.textTheme.bodySmall!.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('INSPIRED BY', style: eyebrow),
        const SizedBox(height: 2),
        Text('ヨルシカ《二人称》', style: theme.textTheme.titleMedium),
      ],
    );
  }
}

/// 底行落款：手写小字年份季节。
class _DateRow extends StatelessWidget {
  const _DateRow();

  @override
  Widget build(BuildContext context) {
    // hwNote(16) 最近档 → 画布 13 淡墨，偏差记录于此
    final TextStyle style = NatsuTypography.hwNote.copyWith(
      fontSize: 13,
      color: KazeColors.inkFaint,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Text('2026 · 夏', style: style),
    );
  }
}
