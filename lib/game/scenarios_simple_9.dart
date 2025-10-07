import 'game_scenario.dart';
import 'game_state.dart';

/// 简单9人局场景
/// 3狼3民3神配置，适合新手
class Simple9PlayersScenario extends GameScenario {
  @override
  String get id => 'simple_9_players';

  @override
  String get name => '简单9人局';

  @override
  String get description => '3狼3民3神配置，规则简单，适合新手练习';

  @override
  int get playerCount => 9;

  @override
  String get difficulty => 'easy';

  @override
  List<String> get tags => ['新手', '简单', '教学'];

  @override
  Map<String, int> get roleDistribution => {
    'werewolf': 3,
    'villager': 3,
    'seer': 1,
    'witch': 1,
    'hunter': 1,
  };

  @override
  String get rulesDescription => '''
- 配置：3狼+3民+预言家+女巫+猎人
- 预言家每晚查验一人（好人/狼人）
- 女巫有解药毒药各一瓶，同夜不能同用
- 猎人死亡可开枪（被毒除外）
- 胜利：好人出清狼/狼人数≥好人数''';

  @override
  List<String> get nightActionPriority => [
    'werewolf',
    'seer',
    'witch',
    // hunter 只在死亡时触发
  ];

  @override
  void initialize(GameState gameState) {
    // 简单局初始化，可以给新手一些提示
    gameState.metadata['is新手模式'] = true;
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
      return GameEndResult.ended(
        winner: 'villager',
        reason: '所有狼人已被淘汰，好人获胜！',
      );
    }

    return GameEndResult.continueGame();
  }

  @override
  String? getNextActionRole(GameState gameState, List<String> completedActions) {
    for (final role in nightActionPriority) {
      if (!completedActions.contains(role)) {
        // 检查是否还有该角色的存活玩家
        final hasAlivePlayer = gameState.players.any((p) =>
            p.isAlive && p.role.roleId == role);

        if (hasAlivePlayer) {
          return role;
        }
      }
    }
    return null;
  }

  @override
  void handlePhaseEnd(GameState gameState) {
    // 简单局可以在阶段结束时给出一些提示
    if (gameState.isDay && gameState.dayNumber == 1) {
      // 第一天白天可以给一些新手提示
      gameState.metadata['day1提示'] = '记住要仔细观察每个人的发言，找出逻辑漏洞';
    }
  }
}