import 'package:flutter/material.dart';
import 'package:signals/signals.dart';
import 'package:werewolf_arena/engine/scenario/game_scenario.dart';
import 'package:werewolf_arena/engine/scenario/scenario_12_players.dart';
import 'package:werewolf_arena/router/router.gr.dart';

class HomeViewModel {
  // 所有可用场景
  final List<GameScenario> _allScenarios = [
    Scenario12Players(),
    // 未来添加更多场景
  ];

  // Signals 状态管理
  late final Signal<List<GameScenario>> scenarios = signal(_allScenarios);
  final Signal<bool> isLoading = signal(false);

  /// 初始化
  Future<void> initSignals() async {
    // 直接使用场景列表，无需加载
  }

  /// 导航到设置页面
  void navigateToSettings(BuildContext context) {
    SettingsRoute().push(context);
  }

  /// 开始场景游戏
  void startScenario(BuildContext context, GameScenario scenario) {
    // 导航到游戏页面，传递场景ID
    GameRoute(scenarioId: scenario.id).push(context);
  }

  /// 显示场景规则详情
  void showScenarioRules(BuildContext context, GameScenario scenario) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(scenario.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                scenario.description,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 16),
              Text(
                scenario.rule,
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('关闭'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              startScenario(context, scenario);
            },
            child: Text('开始游戏'),
          ),
        ],
      ),
    );
  }

  /// 清理资源
  void dispose() {
    scenarios.dispose();
    isLoading.dispose();
  }
}
