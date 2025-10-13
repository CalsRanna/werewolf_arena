import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
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
  bool canCast(GamePlayer player, GameState state) {
    return player.isAlive &&
        player.role.roleId == 'witch' &&
        state.currentPhase.isNight &&
        (player.role.getPrivateData<bool>('has_poison') ?? true);
  }

  @override
  Future<SkillResult?> cast(
    GamePlayer player,
    GameState state, {
    Map<String, dynamic>? aiResponse,
  }) async {
    try {
      // 检查是否还有毒药
      final hasPoison = player.role.getPrivateData<bool>('has_poison') ?? true;
      if (!hasPoison) {
        return null;
      }

      // 获取可毒死的目标（排除自己）
      final availableTargets = state.alivePlayers
          .where((p) => p != player)
          .toList();

      if (availableTargets.isEmpty) {
        return null;
      }

      // 从AI响应中获取毒药目标
      String? target;
      String? message;
      String? reasoning;

      if (aiResponse != null) {
        target = aiResponse['target'] ?? aiResponse['target_id'];
        message = aiResponse['message'];
        reasoning = aiResponse['reasoning'] ?? '';
      }

      // 查找目标玩家
      GamePlayer? targetPlayer;
      if (target != null) {
        final targetStr = target.toString();
        try {
          targetPlayer = state.players.firstWhere((p) => p.name == targetStr);
          // 验证目标是否有效
          if (!availableTargets.contains(targetPlayer)) {
            targetPlayer = null;
          }
        } catch (e) {
          targetPlayer = null;
        }
      }

      // 只有选择了目标才标记毒药已使用
      if (targetPlayer != null) {
        player.role.setPrivateData('has_poison', false);
      }

      return SkillResult(
        caster: player,
        target: targetPlayer,
        message: message,
        reasoning: reasoning ?? '',
      );
    } catch (e) {
      return null;
    }
  }
}
