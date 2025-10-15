import 'package:werewolf_arena/engine/events/dead_event.dart';
import 'package:werewolf_arena/engine/events/judge_announcement_event.dart';
import 'package:werewolf_arena/engine/events/night_result_event.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/skills/speak_skill.dart';
import 'package:werewolf_arena/engine/skills/vote_skill.dart';
import 'game_processor.dart';

/// 白天阶段处理器（基于技能系统重构，包含发言和投票）
///
/// 负责处理游戏中的白天阶段，包括：
/// - 公布夜晚结果
/// - 玩家讨论发言（通过技能系统）
/// - 投票出局（合并原投票阶段）
class DayPhaseProcessor implements GameProcessor {
  @override
  GamePhase get supportedPhase => GamePhase.day;

  @override
  Future<void> process(GameState state, {GameObserver? observer}) async {
    // 2. 公布夜晚结果
    await _announceNightResults(state, observer: observer);

    var players = state.alivePlayers;
    var judgeAnnouncementEvent = JudgeAnnouncementEvent(
      announcement: '所有玩家开始讨论',
    );
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    for (var player in players) {
      await player.executeSkill(
        player.role.skills.whereType<SpeakSkill>().first,
        state,
      );
    }
    judgeAnnouncementEvent = JudgeAnnouncementEvent(
      announcement: '所有玩家讨论结束，开始投票',
    );
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    for (var player in players) {
      await player.executeSkill(
        player.role.skills.whereType<VoteSkill>().first,
        state,
      );
    }
    judgeAnnouncementEvent = JudgeAnnouncementEvent(
      announcement: '所有玩家投票结束，开始结算',
    );
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    // 6. 切换到夜晚阶段（开始新的一天）
    state.dayNumber++;
    await state.changePhase(GamePhase.night);
  }

  /// 公布夜晚结果
  Future<void> _announceNightResults(
    GameState state, {
    GameObserver? observer,
  }) async {
    GameEngineLogger.instance.d('公布夜晚结果');

    // 筛选出今晚的死亡事件
    final deathEvents = state.eventHistory.whereType<DeadEvent>().toList();

    final isPeacefulNight = deathEvents.isEmpty;

    // 创建夜晚结果事件
    final nightResultEvent = NightResultEvent(
      deathEvents: deathEvents,
      isPeacefulNight: isPeacefulNight,
      dayNumber: state.dayNumber,
    );
    state.handleEvent(nightResultEvent);
    await observer?.onGameEvent(nightResultEvent);

    // 记录夜晚结果
    if (isPeacefulNight) {
      GameEngineLogger.instance.i('第${state.dayNumber}夜是平安夜，无人死亡');
    } else {
      final deadPlayers = deathEvents.map((e) => e.victim.name).join('、');
      GameEngineLogger.instance.i('第${state.dayNumber}夜死亡玩家：$deadPlayers');
    }

    // 公布当前存活玩家
    final alivePlayers = state.alivePlayers;
    GameEngineLogger.instance.i(
      '当前存活玩家：${alivePlayers.map((p) => p.name).join('、')}',
    );
  }
}
