import 'package:werewolf_arena/engine/domain/value_objects/speech_type.dart';
import 'package:werewolf_arena/engine/events/dead_event.dart';
import 'package:werewolf_arena/engine/events/judge_announcement_event.dart';
import 'package:werewolf_arena/engine/events/night_result_event.dart';
import 'package:werewolf_arena/engine/events/speak_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';
import 'package:werewolf_arena/engine/skills/skill_processor.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/skills/werewolf_discuss_skill.dart';
import 'phase_processor.dart';

/// 夜晚阶段处理器（基于技能系统重构）
///
/// 负责处理游戏中的夜晚阶段，通过技能系统统一处理所有夜晚行动
class NightPhaseProcessor implements PhaseProcessor {
  final SkillProcessor _skillProcessor = SkillProcessor();

  @override
  GamePhase get supportedPhase => GamePhase.night;

  @override
  Future<void> process(GameState state) async {
    var judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '天黑请闭眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.addEvent(judgeAnnouncementEvent);
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '狼人请睁眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.addEvent(judgeAnnouncementEvent);

    // 2. 收集当前阶段可用技能
    final availableSkills = <GameSkill>[];
    for (final player in state.alivePlayers) {
      final playerSkills = player.role.getAvailableSkills(GamePhase.night);
      for (final skill in playerSkills) {
        if (skill.canCast(player, state)) {
          availableSkills.add(skill);
        }
      }
    }
    final werewolves = state.alivePlayers
        .where((player) => player.role.isWerewolf)
        .toList();
    for (final werewolf in werewolves) {
      var result = await werewolf.executeSkill(
        werewolf.role.skills.whereType<WerewolfDiscussSkill>().first,
        state,
      );
      final discussEvent = SpeakEvent(
        speaker: werewolf,
        message: result.toString(),
        speechType: SpeechType.werewolfDiscussion,
      );
      GameEngineLogger.instance.d(discussEvent.toString());
      state.addEvent(discussEvent);
    }

    // var players = state.players
    //     .where((player) => player.canAct(GamePhase.night) && player.isAlive)
    //     .toList();
    // var skills = players
    //     .expand((player) => player.role.getAvailableSkills(GamePhase.night))
    //     .toList();
    // skills.removeWhere((skill) => !skill.canCast(players, state));

    // 3. 按优先级排序并执行技能
    // availableSkills.sort((a, b) => b.priority.compareTo(a.priority)); // 高优先级在前
    // final skillResults = await _executeSkills(state, availableSkills);

    // // 4. SkillProcessor结算所有技能结果和冲突
    // await _skillProcessor.process(skillResults, state);

    // // 5. 生成夜晚结果事件（所有人可见）
    // _generateNightResultEvents(state, skillResults);

    // // 6. 阶段结束事件（所有人可见）
    // state.addEvent(
    //   PhaseChangeEvent(
    //     oldPhase: GamePhase.night,
    //     newPhase: GamePhase.day,
    //     dayNumber: state.dayNumber,
    //   ),
    // );

    // 7. 切换到白天阶段
    await state.changePhase(GamePhase.day);
  }

  /// 执行技能列表
  Future<List<SkillResult>> _executeSkills(
    GameState state,
    List<GameSkill> availableSkills,
  ) async {
    final results = <SkillResult>[];

    for (final skill in availableSkills) {
      // 找到技能的拥有者 - 使用技能ID而不是对象引用进行匹配
      final player = state.alivePlayers.firstWhere(
        (p) => p.role.skills.any((s) => s.skillId == skill.skillId),
        orElse: () => throw Exception('未找到技能 ${skill.skillId} 的拥有者'),
      );

      try {
        // 使用玩家执行技能
        final result = await player.executeSkill(skill, state);
        results.add(result);
      } catch (e) {
        GameEngineLogger.instance.e('技能执行失败: ${skill.name}, 错误: $e');
        // 创建失败结果
        results.add(SkillResult(success: false, caster: player, target: null));
      }
    }

    return results;
  }

  /// 生成夜晚结果事件
  void _generateNightResultEvents(GameState state, List<SkillResult> results) {
    // 从state中获取今晚的死亡结果，而不是从SkillResult中
    final tonightDeaths = state.deadPlayers
        .where(
          (p) => state.eventHistory.any(
            (event) =>
                event.type.name == 'playerDeath' &&
                event.target == p &&
                // 检查是否是今晚的事件（可以通过事件时间戳或其他方式判断）
                _isEventFromTonight(event),
          ),
        )
        .toList();

    if (tonightDeaths.isEmpty) {
      // 平安夜
      state.addEvent(
        NightResultEvent(
          deathEvents: [],
          isPeacefulNight: true,
          dayNumber: state.dayNumber,
        ),
      );
      GameEngineLogger.instance.i('第${state.dayNumber}夜是平安夜，无人死亡');
    } else {
      // 有人死亡
      final deathEvents = tonightDeaths.map((victim) {
        // 创建死亡事件（这里简化处理，实际应该从事件历史中获取）
        final deadEvent = state.eventHistory
            .whereType<DeadEvent>()
            .where((e) => e.victim == victim && _isEventFromTonight(e))
            .firstOrNull;
        return deadEvent!; // 如果找不到事件则抛出错误
      }).toList();

      state.addEvent(
        NightResultEvent(
          deathEvents: deathEvents,
          isPeacefulNight: false,
          dayNumber: state.dayNumber,
        ),
      );

      final deadPlayerNames = tonightDeaths.map((p) => p.name).join('、');
      GameEngineLogger.instance.i('第${state.dayNumber}夜死亡玩家：$deadPlayerNames');
    }
  }

  /// 检查事件是否是今晚的（简化实现）
  bool _isEventFromTonight(dynamic event) {
    // 这里可以根据事件的时间戳、轮次等信息判断
    // 暂时简化为返回true，实际实现需要更精确的判断逻辑
    return true;
  }
}
