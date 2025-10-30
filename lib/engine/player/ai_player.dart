import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/driver/ai_player_driver.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/skill/skill_result.dart';

/// AI玩家实现
///
/// 使用AIPlayerDriver进行AI决策的玩家实现
class AIPlayer extends GamePlayer {
  AIPlayer({
    required super.id,
    required super.index,
    required AIPlayerDriver driver,
    required super.role,
    required super.name,
  }) : super(driver: driver);

  /// 玩家记忆：存储高质量的结构化上下文
  /// 在每个回合结束时更新，包含对其他玩家的分析、关键事件摘要等
  String memory = '';

  @override
  String get formattedName =>
      '[$name|${role.name}|${(driver as AIPlayerDriver).intelligence.modelId}]';

  @override
  Future<SkillResult> cast(GameSkill skill, GameState state) async {
    try {
      // 使用Driver生成技能响应
      final response = await driver.request(
        player: this,
        state: state,
        skill: skill,
      );
      return SkillResult(
        caster: name,
        target: response.target,
        message: response.message,
        reasoning: response.reasoning,
      );
    } catch (e) {
      return SkillResult(caster: name);
    }
  }
}
