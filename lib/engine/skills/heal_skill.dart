import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
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
  bool canCast(GamePlayer player, GameState state) {
    return player.isAlive &&
        player.role.roleId == 'witch' &&
        state.currentPhase.isNight &&
        (player.role.getPrivateData<bool>('has_antidote') ?? true);
  }

  @override
  Future<SkillResult?> cast(
    GamePlayer player,
    GameState state, {
    Map<String, dynamic>? aiResponse,
  }) async {
    try {
      // 检查是否还有解药
      final hasAntidote =
          player.role.getPrivateData<bool>('has_antidote') ?? true;
      if (!hasAntidote) return null;

      // 从AI响应中获取是否使用解药的决定
      bool useAntidote = false;
      String? message;
      String? reasoning;

      if (aiResponse != null) {
        // 对于解药，可能不需要target，而是一个bool决定
        useAntidote = aiResponse['use_antidote'] ?? false;
        message = aiResponse['message'];
        reasoning = aiResponse['reasoning'] ?? '';
      }

      if (!useAntidote) {
        return SkillResult(
          caster: player,
          target: null,
          message: message,
          reasoning: reasoning ?? '选择不使用解药',
        );
      }

      // 标记解药已使用
      player.role.setPrivateData('has_antidote', false);

      return SkillResult(
        caster: player,
        target: null, // TODO: 设置正确的目标（被救活的玩家）
        message: message,
        reasoning: reasoning ?? '使用解药救活玩家',
      );
    } catch (e) {
      return null;
    }
  }
}
