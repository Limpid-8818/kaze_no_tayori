/// 纸叠切换台 —— 「信纸 ↔ 封筒」视图的原地交换（写信页/读信页共用）。
///
/// 隐喻是更换纸张叠放顺序：换 [child]（凭 Key 判别）时，新纸从上方
/// 轻微抬起后落下落定（压到最上层，driftEasing 缓动），旧纸下沉微缩
/// 淡出（退到叠的下层）。时长走 KazeMotion.long（320ms「纸落桌」）。
///
/// 信纸与封筒高矮悬殊，而 AnimatedSwitcher 的叠在换纸起止两帧会瞬变
/// 到最大者、再瞬塌回独苗——落定帧因此跳位。外层 [AnimatedSize] 把这
/// 两次尺寸突变插值成连续的纸叠收放（与切换同款 long + driftEasing）；
/// [alignment] 同时作两者的锚，默认 topCenter：纸顶钉在滚动流里的
/// 自然位（工具行正下方），高度差全部在纸的下方消化，换纸全程纸不挪位。
///
/// [child] **必须携带 Key**（如 ValueKey('paper') / ValueKey('envelope')）：
/// Key 变化即触发叠放切换；同 Key 重建（内容刷新）不触发动画。
///
/// 跨 feature 复用件按根 CLAUDE.md §1 应上游化进设计系统包（上游化时
/// KazeMotion → NatsuMotion 直连）；同步前暂放 app/widgets，已记入
/// packages/natsu_no_tegami/COPY_IN.md 待上游化清单。
library;

import 'package:flutter/material.dart';

import '../theme.dart';

class KazePaperStack extends StatelessWidget {
  const KazePaperStack({
    required this.child,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  /// 当前视图。必须携带 Key，Key 变化 = 换一张纸。
  final Widget child;

  /// 过渡期新旧视图的对齐锚（AnimatedSize 与内部叠共用；选型见类注释）。
  final Alignment alignment;

  /// 新纸入场：从上方 5% 身高处落下。
  static final Tween<Offset> _settleIn = Tween(
    begin: const Offset(0, -0.05),
    end: Offset.zero,
  );

  /// 旧纸退场：向下沉 4% 身高（沉到叠的下层）。
  static final Tween<Offset> _sinkOut = Tween(
    begin: Offset.zero,
    end: const Offset(0, 0.04),
  );

  /// 旧纸退场的微缩——远一层小一圈，压出叠放纵深。
  static final Tween<double> _sinkScale = Tween(begin: 1.0, end: 0.985);

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: KazeMotion.long,
      curve: KazeMotion.driftEasing,
      alignment: alignment,
      child: AnimatedSwitcher(
        duration: KazeMotion.long,
        switchInCurve: KazeMotion.driftEasing,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: alignment,
          children: [...previousChildren, ?currentChild],
        ),
        // transitionBuilder 对新旧 child 各驱一条 animation：新纸 0→1
        // （switchInCurve），旧纸 1→0（switchOutCurve）。与新视图同 Key
        // 的是正在落下的新纸，另一个是正在下沉的旧纸。
        transitionBuilder: (transitionChild, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: (transitionChild.key == child.key ? _settleIn : _sinkOut)
                .animate(animation),
            child: transitionChild.key == child.key
                ? transitionChild
                : ScaleTransition(
                    scale: _sinkScale.animate(animation),
                    child: transitionChild,
                  ),
          ),
        ),
        child: child,
      ),
    );
  }
}
