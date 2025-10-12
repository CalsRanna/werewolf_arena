import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';

/// 猎人开枪技能（死亡时触发）
///
/// 猎人死亡时可以开枪带走一名玩家，但被毒死时不能开枪
class ShootSkill extends GameSkill {
  @override
  String get skillId => 'hunter_shoot';

  @override
  String get name => '猎人开枪';

  @override
  String get description => '猎人死亡时可以开枪带走一名玩家（被毒除外）';

  @override
  int get priority => 110; // 最高优先级，在死亡确认后立即执行

  @override
  String get prompt => '''
你是猎人，刚刚死亡。现在你可以使用你的猎枪带走一名玩家。

开枪策略：
1. 优先击杀已确认的狼人
2. 击杀最可疑的玩家
3. 考虑击杀对好人阵营威胁最大的玩家
4. 避免击杀已确认的好人
5. 如果不确定，可以选择最可疑的发言者

这是你为好人阵营做出的最后贡献，请谨慎选择。
你的决定可能影响游戏的最终结果。

请选择你要射杀的目标：
''';

  @override
  bool canCast(dynamic player, GameState state) {
    // 只有猎人可以使用此技能
    if (player.role.roleId != 'hunter') {
      return false;
    }

    // 猎人必须已死亡但还没开过枪
    if (player.isAlive) {
      return false;
    }

    // 检查是否已经开过枪
    if (player.role.hasPrivateData('has_shot') &&
        player.role.getPrivateData<bool>('has_shot') == true) {
      return false;
    }

    // 检查是否可以开枪（在onDeath中设置）
    if (!player.role.hasPrivateData('can_shoot') ||
        player.role.getPrivateData<bool>('can_shoot') != true) {
      return false;
    }

    return true;
  }

  @override
  Future<SkillResult> cast(
    dynamic player, 
    GameState state, 
    {Map<String, dynamic>? aiResponse}
  ) async {
    try {
      // 获取可射杀的目标（排除自己，包括所有存活玩家）
      final availableTargets = state.alivePlayers.toList();

      if (availableTargets.isEmpty) {
        return SkillResult.failure(
          caster: player,
          metadata: {
            'skillId': skillId,
            'reason': 'No available targets to shoot',
          },
        );
      }

      // 标记猎人已经开过枪
      player.role.setPrivateData('has_shot', true);
      player.role.setPrivateData('can_shoot', false);

      // 生成猎人开枪技能执行结果
      // 具体的事件创建和目标选择由GameEngine根据玩家决策处理

      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId,
          'availableTargets': availableTargets.length,
          'skillType': 'hunter_shoot',
          'deathShot': true, // 标记这是死亡后的射击
        },
      );
    } catch (e) {
      return SkillResult.failure(
        caster: player,
        metadata: {'skillId': skillId, 'error': e.toString()},
      );
    }
  }
}
