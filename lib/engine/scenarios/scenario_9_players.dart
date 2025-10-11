import 'package:werewolf_arena/engine/domain/entities/role_implementations.dart';
import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/domain/enums/role_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/victory_result.dart';
import 'package:werewolf_arena/engine/scenarios/game_scenario.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 标准9人局场景
/// 2狼3民+预言家+女巫+守卫+猎人配置
class Scenario9Players extends GameScenario {
  @override
  String get id => 'standard_9_players';

  @override
  String get name => '标准9人局';

  @override
  String get description => '经典狼人杀9人局配置';

  @override
  int get playerCount => 9;

  @override
  String get rule => '''
标准狼人杀游戏规则：

游戏目标：
- 好人阵营：消灭所有狼人
- 狼人阵营：狼人数量≥好人数量

游戏流程：
1. 夜晚阶段：狼人击杀、守卫守护、预言家查验、女巫用药
2. 白天阶段：公布结果、玩家发言讨论
3. 投票阶段：投票出局玩家，若平票则PK

角色能力：
- 狼人：夜晚可以击杀一名玩家
- 村民：无特殊能力
- 预言家：夜晚可以查验一名玩家身份
- 女巫：拥有一瓶解药和一瓶毒药
- 守卫：夜晚可以守护一名玩家（不能连续守护同一人）
- 猎人：被投票出局或被狼人击杀时可以开枪带走一名玩家

特殊规则：
- 女巫的解药和毒药不能在同一晚使用
- 守卫不能连续两晚守护同一玩家
- 猎人只有在被投票出局或被狼人击杀时才能开枪
- 平票时进入PK环节，平票玩家发言后重新投票
''';

  @override
  Map<RoleType, int> get roleDistribution => {
    RoleType.werewolf: 2,
    RoleType.villager: 3,
    RoleType.seer: 1,
    RoleType.witch: 1,
    RoleType.guard: 1,
    RoleType.hunter: 1,
  };

  @override
  List<RoleType> getExpandedGameRoles() {
    final roles = <RoleType>[];
    roleDistribution.forEach((role, count) {
      for (int i = 0; i < count; i++) {
        roles.add(role);
      }
    });
    return roles;
  }

  @override
  GameRole createGameRole(RoleType roleType) {
    switch (roleType) {
      case RoleType.werewolf:
        return WerewolfRole();
      case RoleType.villager:
        return VillagerRole();
      case RoleType.seer:
        return SeerRole();
      case RoleType.witch:
        return WitchRole();
      case RoleType.guard:
        return GuardRole();
      case RoleType.hunter:
        return HunterRole();
    }
  }

  @override
  VictoryResult checkVictoryCondition(GameState state) {
    final aliveWerewolves = state.players
        .where((p) => p.isAlive && p.role.isWerewolf)
        .length;

    final aliveGoodGuys = state.players
        .where((p) => p.isAlive && !p.role.isWerewolf)
        .length;

    if (aliveWerewolves == 0) {
      return VictoryResult.goodWins('所有狼人已被消灭');
    }

    if (aliveWerewolves >= aliveGoodGuys) {
      return VictoryResult.evilWins('狼人数量≥好人数量');
    }

    return VictoryResult.gameContinues();
  }
}
