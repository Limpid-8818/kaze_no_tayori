import 'package:flutter/material.dart';

import '../../app/widgets/placeholder_screen.dart';

/// 写信流：正文 → 图(1–3) → 主题 → 音乐引用 → 落点 → **必选**留/投。
///
/// [parentLetterId] 非空即为「回以一封信」：回信是独立作品，写完同样要选留/投，
/// 只是多带一条溯源。**不要把它做成回复输入框。**
class WriteScreen extends StatelessWidget {
  const WriteScreen({this.parentLetterId, super.key});

  final String? parentLetterId;

  @override
  Widget build(BuildContext context) {
    final isReply = parentLetterId != null;
    return PlaceholderScreen(
      title: isReply ? '回以一封信' : '写一封信',
      intent: isReply
          ? '写你自己的作品，它同样可以漂走或埋下。原作者会收到告知，但这封信属于所有会捡到它的人。'
          : '文字（≤800）、图片（1–3）、主题皮肤、音乐引用、AI 润色与短诗，'
                '最后必选「留在这里」或「投递出去」。',
      prdRef: isReply ? '6.5' : '6.1',
    );
  }
}
