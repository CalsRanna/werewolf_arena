import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/core/skills/game_skill.dart';
import 'package:werewolf_arena/core/skills/skill_result.dart';
import 'package:werewolf_arena/core/skills/skill_processor.dart';
import 'package:werewolf_arena/core/events/phase_events.dart';
import 'package:werewolf_arena/core/events/player_events.dart';
import 'package:werewolf_arena/core/logging/game_engine_logger.dart';
import 'package:werewolf_arena/core/logging/game_log_event.dart';
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
    GameEngineLogger.instance.info(
      GameLogCategory.phase,
      '开始处理夜晚阶段 - 第${state.dayNumber}夜',
    );

    // 1. 阶段开始事件（所有人可见）
    state.addEvent(
      PhaseChangeEvent(
        oldPhase: state.currentPhase,
        newPhase: GamePhase.night,
        dayNumber: state.dayNumber,
      ),
    );

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

    // 3. 按优先级排序并执行技能
    availableSkills.sort((a, b) => b.priority.compareTo(a.priority)); // 高优先级在前
    final skillResults = await _executeSkills(state, availableSkills);

    // 4. SkillProcessor结算所有技能结果和冲突
    await _skillProcessor.process(skillResults, state);

    // 5. 生成夜晚结果事件（所有人可见）
    _generateNightResultEvents(state, skillResults);

    // 6. 阶段结束事件（所有人可见）
    state.addEvent(
      PhaseChangeEvent(
        oldPhase: GamePhase.night,
        newPhase: GamePhase.day,
        dayNumber: state.dayNumber,
      ),
    );

    // 7. 切换到白天阶段
    await state.changePhase(GamePhase.day);

    GameEngineLogger.instance.info(GameLogCategory.phase, '夜晚阶段处理完成');
  }

  /// 执行技能列表
  Future<List<SkillResult>> _executeSkills(
    GameState state,
    List<GameSkill> availableSkills,
  ) async {
    final results = <SkillResult>[];

    for (final skill in availableSkills) {
      // 找到技能的拥有者
      final player = state.alivePlayers.firstWhere(
        (p) => p.role.skills.contains(skill),
        orElse: () => throw Exception('未找到技能 ${skill.skillId} 的拥有者'),
      );

      try {
        GameEngineLogger.instance.debug(
          GameLogCategory.skill,
          '执行技能: ${skill.name} (玩家: ${player.name})',
          metadata: {'skill': skill.skillId, 'player': player.name},
        );

        // 使用玩家执行技能
        final result = await player.executeSkill(skill, state);
        results.add(result);

        GameEngineLogger.instance.debug(
          GameLogCategory.skill,
          '技能执行完成: ${skill.name}, 成功: ${result.success}',
          metadata: {'skill': skill.skillId, 'success': result.success},
        );
      } catch (e) {
        GameEngineLogger.instance.error(
          GameLogCategory.skill,
          '技能执行失败: ${skill.name}, 错误: $e',
          metadata: {'skill': skill.skillId, 'error': e},
        );
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
      GameEngineLogger.instance.info(
        GameLogCategory.phase,
        '第${state.dayNumber}夜是平安夜，无人死亡',
        metadata: {'dayNumber': state.dayNumber, 'nightResult': 'peaceful'},
      );
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
      GameEngineLogger.instance.info(
        GameLogCategory.phase,
        '第${state.dayNumber}夜死亡玩家：$deadPlayerNames',
        metadata: {'dayNumber': state.dayNumber, 'deaths': deadPlayerNames},
      );
    }
  }

  /// 检查事件是否是今晚的（简化实现）
  bool _isEventFromTonight(dynamic event) {
    // 这里可以根据事件的时间戳、轮次等信息判断
    // 暂时简化为返回true，实际实现需要更精确的判断逻辑
    return true;
  }
}
