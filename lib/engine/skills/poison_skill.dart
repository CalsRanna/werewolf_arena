import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';

/// 女巫毒药技能（夜晚专用）
///
/// 可以毒死一名玩家，只能使用一次
class PoisonSkill extends GameSkill {
  @override
  String get skillId => 'witch_poison';

  @override
  String get name => '女巫毒药';

  @override
  String get description => '使用毒药杀死一名玩家（限用一次）';

  @override
  int get priority => 95; // 高优先级

  @override
  String get prompt => '''
现在是夜晚阶段，作为女巫，你可以选择使用毒药。

毒药规则：
- 毒药只能使用一次，请慎重考虑
- 毒药可以直接杀死一名玩家
- 毒死的玩家无法被守卫保护

使用策略：
1. 优先毒死确认的狼人
2. 毒死行为可疑的玩家
3. 考虑当前局势，毒药的最大价值
4. 避免毒死明显的好人
5. 关键时刻使用毒药扭转局势

请选择你要毒死的目标。
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive &&
        player.role.roleId == 'witch' &&
        state.currentPhase.isNight &&
        (player.role.getPrivateData<bool>('has_poison') ?? true);
  }

  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 检查是否还有毒药
      final hasPoison = player.role.getPrivateData<bool>('has_poison') ?? true;
      if (!hasPoison) {
        return SkillResult.failure(
          caster: player,
          metadata: {'skillId': skillId, 'reason': 'Poison already used'},
        );
      }

      // 获取可毒死的目标（排除自己）
      final availableTargets = state.alivePlayers
          .where((p) => p != player)
          .toList();

      if (availableTargets.isEmpty) {
        return SkillResult.failure(
          caster: player,
          metadata: {
            'skillId': skillId,
            'reason': 'No available targets to poison',
          },
        );
      }

      // 生成女巫毒药技能执行结果
      // 具体的事件创建由GameEngine根据玩家决策处理

      // 标记毒药已使用
      player.role.setPrivateData('has_poison', false);

      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId,
          'availableTargets': availableTargets.length,
          'skillType': 'witch_poison',
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
