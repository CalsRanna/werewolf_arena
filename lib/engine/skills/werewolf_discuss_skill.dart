import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';
import 'package:werewolf_arena/engine/events/player_events.dart';
import 'package:werewolf_arena/engine/domain/value_objects/speech_type.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';

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
  Future<SkillResult> cast(
    dynamic player, 
    GameState state, 
    {Map<String, dynamic>? aiResponse}
  ) async {
    try {
      // 从AI响应中获取讨论内容
      String discussionContent = '暂时观察情况';
      String? reasoning;
      
      if (aiResponse != null) {
        discussionContent = aiResponse['message']?.toString() ?? 
                           aiResponse['statement']?.toString() ?? 
                           '让我们分析一下今天的情况';
        reasoning = aiResponse['reasoning']?.toString();
      }

      // 创建狼人讨论事件（仅狼人可见）
      final discussEvent = SpeakEvent(
        speaker: player,
        message: discussionContent,
        speechType: SpeechType.werewolfDiscussion,
        dayNumber: state.dayNumber,
        phase: state.currentPhase,
      );

      // 添加事件到游戏状态
      state.addEvent(discussEvent);

      // 记录讨论日志（仅调试可见）
      GameEngineLogger.instance.d('${player.name} 狼人讨论: $discussionContent');
      if (reasoning != null) {
        GameEngineLogger.instance.d('讨论理由: $reasoning');
      }

      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId, 
          'skillType': 'werewolf_discuss',
          'message': discussionContent,
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
