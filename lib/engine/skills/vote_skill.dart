import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';

/// 发言技能（白天专用）
///
/// 玩家在白天阶段的正常发言
class VoteSkill extends GameSkill {
  @override
  String get skillId => 'vote';

  @override
  String get name => '投票';

  @override
  String get description => '在白天阶段进行投票';

  @override
  int get priority => 60; // 普通优先级

  @override
  String get prompt => '''
现在是投票阶段，请选择你要投票出局的玩家。
请基于今天的讨论和你的分析进行投票。
记住，投票出局的玩家将被淘汰。

请选择你要投票的目标：
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && !player.isSilenced && state.currentPhase.isDay;
  }

  @override
  Future<SkillResult> cast(
    dynamic player, 
    GameState state, 
    {Map<String, dynamic>? aiResponse}
  ) async {
    try {
      // 从AI响应中获取投票目标
      dynamic targetName;
      String? reasoning;
      
      if (aiResponse != null) {
        targetName = aiResponse['target'] ?? aiResponse['target_id'];
        reasoning = aiResponse['reasoning']?.toString();
      }

      // 查找目标玩家
      dynamic targetPlayer;
      if (targetName != null) {
        final targetStr = targetName.toString();
        try {
          targetPlayer = state.players.firstWhere(
            (p) => p.name == targetStr,
          );
        } catch (e) {
          // 如果找不到目标玩家，设为null
          targetPlayer = null;
        }
      }

      return SkillResult.success(
        caster: player,
        target: targetPlayer,
        metadata: {
          'skillId': skillId, 
          'speechType': 'normal',
          'target': targetName?.toString(),
          'reasoning': reasoning,
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
