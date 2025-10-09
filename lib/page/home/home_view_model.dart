import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals.dart';
import 'package:werewolf_arena/router/router.gr.dart';
import 'package:werewolf_arena/services/config_service.dart';

class HomeViewModel {
  // 依赖注入的服务
  final ConfigService _configService = GetIt.instance.get<ConfigService>();

  // Signals 状态管理
  final Signal<String> currentScenarioName = signal('');
  final Signal<int> availableScenarioCount = signal(0);
  final Signal<bool> isLoading = signal(false);

  /// 初始化
  Future<void> initSignals() async {
    isLoading.value = true;
    await _loadScenarioInfo();
    isLoading.value = false;
  }

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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '狼人杀是一款经典的社交推理游戏。\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('游戏中，玩家分为狼人阵营和好人阵营。\n'
                  '狼人需要在夜晚杀人，好人需要在白天投票找出狼人。\n'),
              SizedBox(height: 8),
              Text(
                '特殊角色：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• 预言家：每晚可以查验一人身份'),
              Text('• 女巫：拥有一瓶解药和毒药'),
              Text('• 猎人：死亡时可以带走一人'),
              Text('• 守卫：每晚可以守护一人'),
            ],
          ),
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

  /// 显示场景选择对话框
  void showScenarioSelection(BuildContext context) {
    final scenarios = _configService.availableScenarios;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('选择游戏场景'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: scenarios.length,
            itemBuilder: (context, index) {
              final scenario = scenarios[index];
              final isCurrent = scenario.name == currentScenarioName.value;

              return ListTile(
                leading: Icon(
                  isCurrent ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isCurrent ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(scenario.name),
                subtitle: Text('${scenario.playerCount}人局 - ${scenario.description}'),
                onTap: () async {
                  await _configService.setScenario(scenario.id);
                  await _loadScenarioInfo();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 加载场景信息
  Future<void> _loadScenarioInfo() async {
    try {
      currentScenarioName.value = _configService.currentScenarioName;
      availableScenarioCount.value = _configService.availableScenarios.length;
    } catch (e) {
      print('加载场景信息失败: $e');
      currentScenarioName.value = '未知';
      availableScenarioCount.value = 0;
    }
  }

  /// 清理资源
  void dispose() {
    currentScenarioName.dispose();
    availableScenarioCount.dispose();
    isLoading.dispose();
  }
}