import 'package:flutter/material.dart';

import '../../app/widgets/placeholder_screen.dart';

class MyLettersScreen extends StatelessWidget {
  const MyLettersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '我写下的信',
      intent: '我写过的信（含审核中），可下架。这是唯一能看到自己落点的地方。',
      prdRef: '6.13',
    );
  }
}
