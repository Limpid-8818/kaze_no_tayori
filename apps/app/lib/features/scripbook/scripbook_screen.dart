import 'package:flutter/material.dart';

import '../../app/widgets/placeholder_screen.dart';

class ScripbookScreen extends StatelessWidget {
  const ScripbookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '抄本',
      intent: '我收藏的信。个人行为，不计入公开互动。',
      prdRef: '6.10',
    );
  }
}
