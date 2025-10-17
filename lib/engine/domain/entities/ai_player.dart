import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/drivers/ai_player_driver.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';

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
      print(e);
      return SkillResult(caster: name);
    }
  }
}
