import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';

/// 预言家查验技能（夜晚专用）
///
/// 查验玩家身份，结果只有预言家可见
class InvestigateSkill extends GameSkill {
  @override
  String get skillId => 'seer_check';

  @override
  String get name => '预言家查验';

  @override
  String get description => '夜晚可以查验一名玩家的身份（好人或狼人）';

  @override
  int get priority => 80; // 中等优先级

  @override
  String get prompt => '''
现在是夜晚阶段，作为预言家，你需要选择查验目标。

查验策略：
1. 优先查验可疑的玩家
2. 查验白天发言异常的玩家
3. 查验投票行为可疑的玩家
4. 避免查验明显的好人
5. 建立查验序列，系统性地收集信息

查验结果将只有你能看到：
- 如果是狼人，你会得到"狼人"的结果
- 如果是好人，你会得到"好人"的结果

请选择你要查验的目标。
''';

  @override
  bool canCast(GamePlayer player, GameState state) {
    return player.isAlive &&
        player.role.roleId == 'seer' &&
        state.currentPhase.isNight;
  }

  @override
  Future<SkillResult?> cast(
    GamePlayer player,
    GameState state, {
    Map<String, dynamic>? aiResponse,
  }) async {
    try {
      // 获取可查验的目标（排除自己）
      final availableTargets = state.alivePlayers
          .where((p) => p != player)
          .toList();

      if (availableTargets.isEmpty) {
        return null;
      }

      // 从AI响应中获取查验目标
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
