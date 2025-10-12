import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';

/// 女巫解药技能（夜晚专用）
///
/// 可以救活当晚被狼人击杀的玩家，只能使用一次
class HealSkill extends GameSkill {
  @override
  String get skillId => 'witch_heal';

  @override
  String get name => '女巫解药';

  @override
  String get description => '使用解药救活被狼人击杀的玩家（限用一次）';

  @override
  int get priority => 85; // 高优先级，在狼人击杀之后执行

  @override
  String get prompt => '''
现在是夜晚阶段，作为女巫，你可以选择使用解药。

解药规则：
- 解药只能使用一次，请慎重考虑
- 解药可以救活今晚被狼人击杀的玩家
- 你会知道今晚谁被狼人击杀了

使用建议：
1. 如果死的是重要神职，优先考虑救活
2. 如果死的是自己的盟友，可以考虑救活
3. 保留解药用于关键时刻
4. 考虑当前局势，解药的价值

是否使用解药救活被击杀的玩家？
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive &&
        player.role.roleId == 'witch' &&
        state.currentPhase.isNight &&
        (player.role.getPrivateData<bool>('has_antidote') ?? true);
  }

  @override
  Future<SkillResult> cast(
    dynamic player, 
    GameState state, 
    {Map<String, dynamic>? aiResponse}
  ) async {
    try {
      // 检查是否还有解药
      final hasAntidote =
          player.role.getPrivateData<bool>('has_antidote') ?? true;
      if (!hasAntidote) {
        return SkillResult.failure(
          caster: player,
          metadata: {'skillId': skillId, 'reason': 'Antidote already used'},
        );
      }

      // 检查是否有玩家被击杀（临时注释掉nightActions引用）
      // TODO: 从skillEffects或事件历史中获取受害者信息
      // final tonightVictim = state.nightActions.tonightVictim;
      // if (tonightVictim == null) {
      //   return SkillResult.failure(
      //     caster: player,
      //     metadata: {
      //       'skillId': skillId,
      //       'reason': 'No one was killed tonight',
      //     },
      //   );
      // }

      // 生成女巫治疗技能执行结果
      // 具体的事件创建由GameEngine处理

      // 标记解药已使用
      player.role.setPrivateData('has_antidote', false);

      return SkillResult.success(
        caster: player,
        target: null, // TODO: 设置正确的目标
        metadata: {
          'skillId': skillId,
          'victimName': 'unknown', // TODO: 从skillEffects获取受害者名称
          'skillType': 'witch_heal',
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
