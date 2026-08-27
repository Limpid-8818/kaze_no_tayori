/// 应用级生命周期入口。需要“回前台刷新”的全局能力统一挂在这里。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/location_controller.dart';
import 'controllers/unread_count_controller.dart';

class AppLifecycle extends ConsumerStatefulWidget {
  const AppLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLifecycle> createState() => _AppLifecycleState();
}

class _AppLifecycleState extends ConsumerState<AppLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 开页首拉（F5 未读数角标）。post-frame：等首帧挂上 provider 再取。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(unreadCountControllerProvider.notifier).refresh());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _refreshGlobalState();
  }

  Future<void> _refreshGlobalState() async {
    // LocationController 内部同时刷新权限，并把插件异常显式落到 failed；
    // 避免生命周期的未等待 Future 把错误抛到框架区。未读数失败自吞。
    await ref.read(locationControllerProvider.notifier).refreshIfActive();
    unawaited(ref.read(unreadCountControllerProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
