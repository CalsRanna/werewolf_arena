import 'package:werewolf_arena/core/scenarios/game_scenario.dart';
import 'package:werewolf_arena/core/state/game_state.dart';

/// 标准12人局场景
/// 4狼+4民+4神配置，无警长
class Standard12PlayersScenario extends GameScenario {
  @override
  String get id => 'standard_12_players';

  @override
  String get name => '标准12人局';

  @override
  String get description => '经典4狼4民4神配置，无警长，适合平衡的游戏体验';

  @override
  int get playerCount => 12;

  @override
  String get difficulty => 'medium';

  @override
  List<String> get tags => ['经典', '平衡', '无警长'];

  @override
  Map<String, int> get roleDistribution => {
    'werewolf': 4,
    'villager': 4,
    'seer': 1,
    'witch': 1,
    'hunter': 1,
    'guard': 1,
  };

  @override
  String get rulesDescription => '''
- 配置：4狼+4民+预言家+女巫+猎人+守卫
- 重要：无警长无警徽，禁提相关术语
- 预言家每晚查验一人（好人/狼人）
- 女巫有解药毒药各一瓶，同夜不能同用
- 猎人死亡可开枪（被毒除外）
- 守卫每晚守一人，不能连守，同守同救死
- 胜利：好人出清狼/狼人数≥好人数''';

  @override
  List<String> get nightActionPriority => [
    'guard',
    'werewolf',
    'seer',
    'witch',
    // hunter 只在死亡时触发
  ];

  @override
  void initialize(GameState gameState) {
    // 标准局不需要特殊初始化
    // 可以在这里设置一些初始状态或标记
  }

  @override
  GameEndResult checkGameEnd(GameState gameState) {
    final aliveWerewolves = gameState.players
        .where((p) => p.isAlive && p.role.isWerewolf)
        .length;

    final aliveVillagers = gameState.players
        .where((p) => p.isAlive && p.role.isVillager)
        .length;

    // 狼人胜利条件：狼人数量 >= 好人数量
    if (aliveWerewolves >= aliveVillagers) {
      return GameEndResult.ended(
        winner: 'werewolf',
        reason: '狼人数量已经不少于好人数量，狼人获胜！',
      );
    }

    // 好人胜利条件：所有狼人被淘汰
    if (aliveWerewolves == 0) {
      return GameEndResult.ended(winner: 'villager', reason: '所有狼人已被淘汰，好人获胜！');
    }

    return GameEndResult.continueGame();
  }

  @override
  String? getNextActionRole(
    GameState gameState,
    List<String> completedActions,
  ) {
    for (final role in nightActionPriority) {
      if (!completedActions.contains(role)) {
        // 检查是否还有该角色的存活玩家
        final hasAlivePlayer = gameState.players.any(
          (p) => p.isAlive && p.role.roleId == role,
        );

        if (hasAlivePlayer) {
          return role;
        }
      }
    }
    return null;
  }

  @override
  void handlePhaseEnd(GameState gameState) {
    // 标准局在阶段结束时不需要特殊处理
    // 可以在这里添加一些场景特定的逻辑
  }
}
