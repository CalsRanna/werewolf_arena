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
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 生成发言技能执行结果
      // 具体的事件创建由GameEngine根据玩家输入处理

      return SkillResult.success(
        caster: player,
        metadata: {'skillId': skillId, 'speechType': 'normal'},
      );
    } catch (e) {
      return SkillResult.failure(
        caster: player,
        metadata: {'skillId': skillId, 'error': e.toString()},
      );
    }
  }
}
