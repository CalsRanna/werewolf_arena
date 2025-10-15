import 'package:werewolf_arena/engine/domain/entities/guard_role.dart';
import 'package:werewolf_arena/engine/domain/entities/hunter_role.dart';
import 'package:werewolf_arena/engine/domain/entities/seer_role.dart';
import 'package:werewolf_arena/engine/domain/entities/witch_role.dart';
import 'package:werewolf_arena/engine/events/judge_announcement_event.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/skills/heal_skill.dart';
import 'package:werewolf_arena/engine/skills/investigate_skill.dart';
import 'package:werewolf_arena/engine/skills/kill_skill.dart';
import 'package:werewolf_arena/engine/skills/poison_skill.dart';
import 'package:werewolf_arena/engine/skills/protect_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/skills/werewolf_discuss_skill.dart';
import 'game_processor.dart';

/// 夜晚阶段处理器（基于技能系统重构）
///
/// 负责处理游戏中的夜晚阶段，通过技能系统统一处理所有夜晚行动
class NightPhaseProcessor implements GameProcessor {
  @override
  GamePhase get supportedPhase => GamePhase.night;

  @override
  Future<void> process(GameState state, {GameObserver? observer}) async {
    var judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '天黑请闭眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '狼人请睁眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    final werewolves = state.alivePlayers
        .where((player) => player.role.isWerewolf)
        .toList();
    for (final werewolf in werewolves) {
      await werewolf.executeSkill(
        werewolf.role.skills.whereType<WerewolfDiscussSkill>().first,
        state,
      );
    }
    judgeAnnouncementEvent = JudgeAnnouncementEvent(
      announcement: '请选择你们要击杀的玩家',
    );
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    List<Future<SkillResult?>> futures = [];
    for (final werewolf in werewolves) {
      var future = werewolf.executeSkill(
        werewolf.role.skills.whereType<KillSkill>().first,
        state,
      );
      futures.add(future);
    }
    await Future.wait(futures);
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '预言家请睁眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    final seer = state.alivePlayers
        .where((player) => player.role is SeerRole)
        .first;
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '你要查验的玩家是谁');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    await seer.executeSkill(
      seer.role.skills.whereType<InvestigateSkill>().first,
      state,
    );
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '预言家请闭眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '女巫请睁眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    final witch = state.alivePlayers
        .where((player) => player.role is WitchRole)
        .first;
    judgeAnnouncementEvent = JudgeAnnouncementEvent(
      announcement: '昨晚 号玩家死亡，你有一瓶解药，你要用吗',
    );
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    await witch.executeSkill(
      witch.role.skills.whereType<HealSkill>().first,
      state,
    );
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    judgeAnnouncementEvent = JudgeAnnouncementEvent(
      announcement: '你有一瓶毒药，你要用吗',
    );
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    await witch.executeSkill(
      witch.role.skills.whereType<PoisonSkill>().first,
      state,
    );
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '女巫请闭眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '守卫请睁眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    final guard = state.alivePlayers
        .where((player) => player.role is GuardRole)
        .first;
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '你要守护的玩家是谁');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    await guard.executeSkill(
      guard.role.skills.whereType<ProtectSkill>().first,
      state,
    );
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '守卫请闭眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '猎人请睁眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    final hunter = state.alivePlayers
        .where((player) => player.role is HunterRole)
        .first;
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '猎人请闭眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '天亮了');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);

    // 7. 切换到白天阶段
    await state.changePhase(GamePhase.day);
  }
}
