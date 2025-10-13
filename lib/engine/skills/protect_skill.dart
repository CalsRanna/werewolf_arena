import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';

/// 守卫保护技能（夜晚专用）
///
/// 包含守护规则：不能连续两晚守护同一人
class ProtectSkill extends GameSkill {
  @override
  String get skillId => 'guard_protect';

  @override
  String get name => '守卫保护';

  @override
  String get description => '夜晚可以守护一名玩家，保护其免受狼人击杀';

  @override
  int get priority => 90; // 高优先级，在狼人击杀之后执行

  @override
  String get prompt => '''
现在是夜晚阶段，作为守卫，你需要选择守护目标。

守护规则：
- 你不能连续两晚守护同一名玩家
- 守护可以保护玩家免受狼人击杀
- 如果你守护的玩家被狼人击杀，他们将存活

策略建议：
1. 优先保护可能的神职玩家
2. 观察白天谁的发言最有价值
3. 考虑狼人的击杀偏好
4. 必要时可以守护自己（除非昨晚已守护）
5. 避免守护明显的村民

请选择你要守护的目标。
''';

  @override
  bool canCast(GamePlayer player, GameState state) {
    return player.isAlive &&
        player.role.roleId == 'guard' &&
        state.currentPhase.isNight;
  }

  @override
  Future<SkillResult?> cast(
    GamePlayer player,
    GameState state, {
    Map<String, dynamic>? aiResponse,
  }) async {
    try {
      // 获取上次守护的玩家
      final lastProtected = player.role.getPrivateData<String>(
        'last_protected',
      );

      // 获取可守护的目标（排除上次守护的玩家）
      final availableTargets = state.alivePlayers.where((p) {
        if (lastProtected != null && p.name == lastProtected) {
          return false; // 不能连续守护同一人
        }
        return true;
      }).toList();

      if (availableTargets.isEmpty) {
        return null;
      }

      // 从AI响应中获取保护目标
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
