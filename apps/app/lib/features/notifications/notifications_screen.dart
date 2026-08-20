import 'package:flutter/material.dart';

import '../../app/widgets/placeholder_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '回信告知',
      intent: '「你于某地写的那封信，收到一封回信 ✦」。只是获知，不是私信。',
      prdRef: '6.5',
    );
  }
}
