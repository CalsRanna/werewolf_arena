import 'package:flutter/material.dart';
import 'package:werewolf_arena/router/router.gr.dart';

class HomeViewModel {
  /// 导航到游戏页面
  void navigateToGame(BuildContext context) {
    GameRoute().push(context);
  }

  /// 导航到设置页面
  void navigateToSettings(BuildContext context) {
    SettingsRoute().push(context);
  }

  /// 开始新游戏
  void startNewGame(BuildContext context) {
    navigateToGame(context);
  }

  /// 显示游戏规则
  void showGameRules(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('游戏规则'),
        content: Text(
          '狼人杀是一款经典的社交推理游戏。\n\n'
          '游戏中，玩家分为狼人阵营和好人阵营。\n'
          '狼人需要在夜晚杀人，好人需要在白天投票找出狼人。\n\n'
          '特殊角色：\n'
          '• 预言家：每晚可以查验一人身份\n'
          '• 女巫：拥有一瓶解药和毒药\n'
          '• 猎人：死亡时可以带走一人\n'
          '• 守卫：每晚可以守护一人',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('知道了'),
          ),
        ],
      ),
    );
  }
}