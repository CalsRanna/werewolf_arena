import 'package:werewolf_arena/engine/role/guard_role.dart';
import 'package:werewolf_arena/engine/role/hunter_role.dart';
import 'package:werewolf_arena/engine/role/game_role.dart';
import 'package:werewolf_arena/engine/role/seer_role.dart';
import 'package:werewolf_arena/engine/role/villager_role.dart';
import 'package:werewolf_arena/engine/role/werewolf_role.dart';
import 'package:werewolf_arena/engine/role/witch_role.dart';
import 'package:werewolf_arena/engine/scenario/game_scenario.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';

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

游戏目标（屠边）：
- 好人阵营：所有狼人被消灭
- 狼人阵营：所有村民被消灭或者所有神职被消灭

游戏流程：
1. 夜晚阶段：守卫守护、狼人击杀、预言家查验、女巫用药
2. 白天阶段：公布结果、玩家发言讨论
3. 投票阶段：投票出局玩家

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
''';

  @override
  String? checkVictoryCondition(GameState state) {
    final aliveWerewolves = state.aliveWerewolves;
    final aliveGods = state.gods.where((p) => p.isAlive).length;
    final aliveVillagers = state.aliveVillagers;

    // 好人胜利：所有狼人死亡
    if (aliveWerewolves == 0) {
      GameEngineLogger.instance.i('好人阵营获胜！所有狼人已出局');
      return '好人阵营';
    }

    // 狼人胜利（屠边规则）：
    // 条件1：屠神边 - 所有神职死亡且狼人数量 >= 平民数量
    if (state.gods.isNotEmpty && aliveGods == 0) {
      if (aliveWerewolves >= aliveVillagers) {
        GameEngineLogger.instance.i('狼人阵营获胜！屠神成功（所有神职已出局，狼人占优势）');
        return '狼人阵营';
      }
    }

    // 条件2：屠民边 - 所有平民死亡且狼人数量 >= 神职数量
    if (state.villagers.isNotEmpty && aliveVillagers == 0) {
      if (aliveWerewolves >= aliveGods) {
        GameEngineLogger.instance.i('狼人阵营获胜！屠民成功（所有平民已出局，狼人占优势）');
        return '狼人阵营';
      }
    }

    // 游戏继续
    return null;
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
