import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';
import 'package:werewolf_arena/engine/events/player_events.dart';
import 'package:werewolf_arena/engine/domain/value_objects/speech_type.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';

/// 发言技能（白天专用）
///
/// 玩家在白天阶段的正常发言
class SpeakSkill extends GameSkill {
  @override
  String get skillId => 'speak';

  @override
  String get name => '发言';

  @override
  String get description => '在白天阶段进行发言讨论';

  @override
  int get priority => 50; // 普通优先级

  @override
  String get prompt => '''
现在是白天讨论阶段，请进行你的发言。

你可以选择以下发言策略：
1. 分享信息：公布你掌握的信息（如果你是神职）
2. 分析推理：分析昨晚的结果和玩家行为
3. 表达怀疑：指出你怀疑的玩家并说明理由
4. 为自己辩护：如果被怀疑，为自己澄清
5. 引导投票：建议大家投票给特定玩家

发言要点：
- 保持逻辑性和说服力
- 根据你的角色身份调整发言策略
- 观察其他玩家的反应
- 为接下来的投票做准备

请发表你的观点：
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
      // 从AI响应中获取发言内容
      String speechContent = '暂时保持沉默';
      String? reasoning;
      
      if (aiResponse != null) {
        speechContent = aiResponse['message']?.toString() ?? 
                       aiResponse['statement']?.toString() ?? 
                       '我认为今天需要仔细分析情况';
        reasoning = aiResponse['reasoning']?.toString();
      }

      // 创建发言事件
      final speakEvent = SpeakEvent(
        speaker: player,
        message: speechContent,
        speechType: SpeechType.normal,
        dayNumber: state.dayNumber,
        phase: state.currentPhase,
      );

      // 添加事件到游戏状态
      state.addEvent(speakEvent);

      // 记录发言日志
      GameEngineLogger.instance.i('${player.name} 发言: $speechContent');
      if (reasoning != null) {
        GameEngineLogger.instance.d('发言理由: $reasoning');
      }

      return SkillResult.success(
        caster: player,
        metadata: {
          'skillId': skillId, 
          'speechType': 'normal',
          'message': speechContent,
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
