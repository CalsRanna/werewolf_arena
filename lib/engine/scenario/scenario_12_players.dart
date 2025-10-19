import 'package:werewolf_arena/engine/role/guard_role.dart';
import 'package:werewolf_arena/engine/role/hunter_role.dart';
import 'package:werewolf_arena/engine/role/game_role.dart';
import 'package:werewolf_arena/engine/role/seer_role.dart';
import 'package:werewolf_arena/engine/role/villager_role.dart';
import 'package:werewolf_arena/engine/role/werewolf_role.dart';
import 'package:werewolf_arena/engine/role/witch_role.dart';
import 'package:werewolf_arena/engine/game_result.dart';
import 'package:werewolf_arena/engine/scenario/game_scenario.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 标准12人局场景
/// 4狼4民+4神配置，无警长
class Scenario12Players extends GameScenario {
  @override
  String get id => 'standard_12_players';

  @override
  String get name => '标准12人局';

  @override
  String get description => '经典4狼4民4神配置，无警长';

  @override
  String get rule => '''
标准12人局狼人杀游戏规则：

游戏目标：
- 好人阵营：消灭所有狼人
- 狼人阵营：狼人数量≥好人数量

游戏流程：
1. 夜晚阶段：守卫守护、狼人击杀、预言家查验、女巫用药
2. 白天阶段：公布结果、玩家发言讨论
3. 投票阶段：投票出局玩家，若平票则PK

角色配置（4狼4民4神）：
- 狼人×4：夜晚可以击杀一名玩家
- 村民×4：无特殊能力
- 预言家×1：夜晚可以查验一名玩家身份
- 女巫×1：拥有一瓶解药和一瓶毒药
- 守卫×1：夜晚可以守护一名玩家（不能连续守护同一人）
- 猎人×1：被投票出局或被狼人击杀时可以开枪带走一名玩家

特殊规则：
- 无警长无警徽，禁提相关术语
- 女巫的解药和毒药不能在同一晚使用
- 守卫不能连续两晚守护同一玩家，同守同救死
- 猎人只有在被投票出局或被狼人击杀时才能开枪（被毒除外）
- 平票时进入PK环节，平票玩家发言后重新投票
''';

  @override
  GameResult checkVictoryCondition(GameState state) {
    final aliveWerewolves = state.players
        .where((p) => p.isAlive && p.role.id == 'werewolf')
        .length;

    final aliveGoodGuys = state.players
        .where((p) => p.isAlive && p.role.id != 'werewolf')
        .length;

    if (aliveWerewolves == 0) {
      return GameResult.goodWins('所有狼人已被消灭');
    }

    if (aliveWerewolves >= aliveGoodGuys) {
      return GameResult.evilWins('狼人数量≥好人数量');
    }

    return GameResult.gameContinues();
  }

  @override
  List<GameRole> get roles => [
    WerewolfRole(),
    WerewolfRole(),
    WerewolfRole(),
    WerewolfRole(),
    VillagerRole(),
    VillagerRole(),
    VillagerRole(),
    VillagerRole(),
    SeerRole(),
    WitchRole(),
    GuardRole(),
    HunterRole(),
  ];
}
