import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/driver/ai_player_driver.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/memory/working_memory.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/skill/skill_result.dart';

/// AI玩家实现
///
/// 使用AIPlayerDriver进行AI决策的玩家实现
class AIPlayer extends GamePlayer {
  /// 工作记忆：存储结构化的游戏记忆
  /// 在推理过程中更新和使用
  WorkingMemory? workingMemory;

  /// 元数据：存储统计信息（如token使用量等）
  final Map<String, dynamic> metadata = {};

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
      return SkillResult(caster: name);
    }
  }
}
