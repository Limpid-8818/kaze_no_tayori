import 'package:flutter/material.dart';

import '../../app/widgets/placeholder_screen.dart';

class DriftScreen extends StatelessWidget {
  const DriftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '随机漂流',
      intent: '抽一封陌生人漂来的信：非自己所写、未读过。纯随机，不做任何加权。',
      prdRef: '6.3',
    );
  }
}
