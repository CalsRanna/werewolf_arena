import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';

/// 狼人讨论技能（夜晚专用）
///
/// 狼人之间的私密讨论，只有狼人可见
class WerewolfDiscussSkill extends GameSkill {
  @override
  String get skillId => 'werewolf_discuss';

  @override
  String get name => '狼人讨论';

  @override
  String get description => '与狼人队友进行私密讨论';

  @override
  int get priority => 110; // 最高优先级，在击杀之前进行讨论

  @override
  String get prompt => '''
现在是夜晚阶段，作为狼人，你可以与队友进行私密讨论。

讨论内容建议：
1. 分析今天白天的发言
2. 识别可能的神职玩家
3. 讨论击杀策略
4. 协调明天白天的发言策略
5. 分析投票情况

只有狼人能看到这些讨论内容。
请发表你的观点和建议。
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive &&
        player.role.isWerewolf &&
        state.currentPhase.isNight;
  }

  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    try {
      // 生成狼人讨论技能执行结果
      // 具体的事件创建由GameEngine根据玩家输入处理

      return SkillResult.success(
        caster: player,
        metadata: {'skillId': skillId, 'skillType': 'werewolf_discuss'},
      );
    } catch (e) {
      return SkillResult.failure(
        caster: player,
        metadata: {'skillId': skillId, 'error': e.toString()},
      );
    }
  }
}
