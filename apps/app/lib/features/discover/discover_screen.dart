import 'package:flutter/material.dart';

import '../../app/widgets/placeholder_screen.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '就地发掘',
      intent: '按当前位置检索附近「留在这里」的信，让同地陌生人跨越时间对话。',
      prdRef: '6.4',
    );
  }
}
