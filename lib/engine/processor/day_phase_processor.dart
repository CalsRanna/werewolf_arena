import 'package:werewolf_arena/engine/game_phase.dart';
import 'package:werewolf_arena/engine/event/dead_event.dart';
import 'package:werewolf_arena/engine/event/judge_announcement_event.dart';
import 'package:werewolf_arena/engine/event/speak_event.dart';
import 'package:werewolf_arena/engine/event/speech_order_announcement_event.dart';
import 'package:werewolf_arena/engine/event/vote_event.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skill/skill_result.dart';
import 'package:werewolf_arena/engine/skill/discuss_skill.dart';
import 'package:werewolf_arena/engine/skill/vote_skill.dart';

import 'game_processor.dart';

/// 白天阶段处理器（基于技能系统重构，包含发言和投票）
///
/// 负责处理游戏中的白天阶段，包括：
/// - 公布夜晚结果
/// - 玩家讨论发言（通过技能系统）
/// - 投票出局（合并原投票阶段）
class DayPhaseProcessor implements GameProcessor {
  @override
  Future<void> process(GameState state, {GameObserver? observer}) async {
    var players = state.alivePlayers;
    var judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '开始讨论');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    var speakingOrder = SpeechOrderAnnouncementEvent(
      speakingOrder: state.alivePlayers,
      direction: '顺序',
    );
    GameEngineLogger.instance.d(speakingOrder.toString());
    state.handleEvent(speakingOrder);
    await observer?.onGameEvent(speakingOrder);
    for (var player in players) {
      var result = await player.cast(
        player.role.skills.whereType<DiscussSkill>().first,
        state,
      );
      var speakEvent = SpeakEvent(
        speaker: player,
        message: result.message ?? '',
      );
      state.handleEvent(speakEvent);
      await observer?.onGameEvent(speakEvent);
    }
    judgeAnnouncementEvent = JudgeAnnouncementEvent(
      announcement: '所有玩家讨论结束，开始投票',
    );
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    List<Future<SkillResult>> futures = [];
    for (var player in players) {
      futures.add(
        player.cast(player.role.skills.whereType<VoteSkill>().first, state),
      );
    }
    var results = await Future.wait(futures);
    judgeAnnouncementEvent = JudgeAnnouncementEvent(
      announcement: '所有玩家投票结束，开始结算',
    );
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);

    for (var result in results) {
      if (result.target == null) continue;
      var voteEvent = VoteEvent(
        voter: state.getPlayerByName(result.caster)!,
        candidate: state.getPlayerByName(result.target!)!,
      );
      state.handleEvent(voteEvent);
      await observer?.onGameEvent(voteEvent);
    }

    ///统计得票最多的玩家出局
    var map = <String, int>{};
    for (var result in results) {
      if (result.target == null) continue;
      map[result.target!] = (map[result.target!] ?? 0) + 1;
    }
    var targetPlayerName = map.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    var targetPlayer = state.getPlayerByName(targetPlayerName);
    if (targetPlayer != null) {
      targetPlayer.setAlive(false);
    }
    var deadEvent = DeadEvent(victim: targetPlayer!);
    state.handleEvent(deadEvent);
    await observer?.onGameEvent(deadEvent);
    // 6. 切换到夜晚阶段（开始新的一天）
    state.dayNumber++;
    await state.changePhase(GamePhase.night);
  }
}
