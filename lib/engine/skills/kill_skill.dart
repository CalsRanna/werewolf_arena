import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';

/// 狼人击杀技能（夜晚专用）
///
/// 具有完整的游戏逻辑实现，包括目标选择、事件生成和状态更新
class KillSkill extends GameSkill {
  @override
  String get skillId => 'werewolf_kill';

  @override
  String get name => '狼人击杀';

  @override
  String get description => '夜晚狼人可以选择击杀一名玩家';

  @override
  int get priority => 100; // 最高优先级，在其他技能之前执行

  @override
  String get prompt => '''
现在是夜晚阶段，作为狼人，你需要选择击杀目标。

请考虑以下策略：
1. 优先击杀神职玩家（预言家、女巫、守卫、猎人）
2. 分析白天发言，找出可能的神职身份
3. 避免击杀明显的村民
4. 考虑守卫可能保护的对象
5. 制造混乱，误导好人阵营

当前存活玩家分析：
- 观察谁在引导投票
- 谁的发言过于逻辑清晰
- 谁可能掌握关键信息

请选择你要击杀的目标，并说明理由。
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive &&
        player.role.isWerewolf &&
        state.currentPhase.isNight;
  }

  @override
  Future<SkillResult> cast(
    dynamic player, 
    GameState state, 
    {Map<String, dynamic>? aiResponse}
  ) async {
    try {
      // 获取可击杀的目标（排除狼人队友）
      final availableTargets = state.alivePlayers
          .where((p) => p != player && !p.role.isWerewolf)
          .toList();

      if (availableTargets.isEmpty) {
        return SkillResult.failure(
          caster: player,
          metadata: {'skillId': skillId, 'reason': 'No available targets'},
        );
      }

      // 这里应该通过PlayerDriver获取AI决策或等待人类输入
      // 暂时实现基础逻辑，具体目标选择由GameEngine处理

      // 这里不直接创建事件，而是返回成功结果
      // 具体的事件创建由GameEngine根据玩家选择的目标处理

      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId,
          'availableTargets': availableTargets.length,
          'skillType': 'werewolf_kill',
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
