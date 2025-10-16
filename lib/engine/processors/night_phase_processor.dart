import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/entities/guard_role.dart';
import 'package:werewolf_arena/engine/domain/entities/hunter_role.dart';
import 'package:werewolf_arena/engine/domain/entities/seer_role.dart';
import 'package:werewolf_arena/engine/domain/entities/witch_role.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/events/dead_event.dart';
import 'package:werewolf_arena/engine/events/guard_protect_event.dart';
import 'package:werewolf_arena/engine/events/hunter_shoot_event.dart';
import 'package:werewolf_arena/engine/events/judge_announcement_event.dart';
import 'package:werewolf_arena/engine/events/seer_investigate_event.dart';
import 'package:werewolf_arena/engine/events/werewolf_discussion_event.dart';
import 'package:werewolf_arena/engine/events/werewolf_kill_event.dart';
import 'package:werewolf_arena/engine/events/witch_heal_event.dart';
import 'package:werewolf_arena/engine/events/witch_poison_event.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/heal_skill.dart';
import 'package:werewolf_arena/engine/skills/investigate_skill.dart';
import 'package:werewolf_arena/engine/skills/kill_skill.dart';
import 'package:werewolf_arena/engine/skills/poison_skill.dart';
import 'package:werewolf_arena/engine/skills/protect_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';
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
    // 狼人讨论战术
    await _processWerewolfDiscussion(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 狼人杀人
    final killTarget = await _processWerewolfKill(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 预言家查验
    await _processSeerInvestigate(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 女巫救人
    final healTarget = await _processWitchHeal(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 女巫下毒
    final poisonTarget = await _processWitchPoison(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 守卫守护
    final guardTarget = await _processGuardProtect(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 猎人杀人
    final shootTarget = await _processHunterKill(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 夜晚结算
    await _processNightSettlement(
      state,
      observer: observer,
      killTarget: killTarget,
      healTarget: healTarget,
      poisonTarget: poisonTarget,
      guardTarget: guardTarget,
      shootTarget: shootTarget,
    );
    await Future.delayed(const Duration(seconds: 1));
    await state.changePhase(GamePhase.day);
  }

  Future<void> _processNightSettlement(
    GameState state, {
    GameObserver? observer,
    GamePlayer? killTarget,
    GamePlayer? healTarget,
    GamePlayer? poisonTarget,
    GamePlayer? guardTarget,
    GamePlayer? shootTarget,
  }) async {
    final lastAlivePlayers = state.alivePlayers;
    if (killTarget != null) {
      final killEvent = WerewolfKillEvent(target: killTarget);
      state.handleEvent(killEvent);
      await observer?.onGameEvent(killEvent);
      final player = state.getPlayerByName(killTarget.name);
      if (player != null) {
        player.setAlive(false);
      }
    }
    if (healTarget != null) {
      final healEvent = WitchHealEvent(target: healTarget);
      state.handleEvent(healEvent);
      await observer?.onGameEvent(healEvent);
      final player = state.getPlayerByName(healTarget.name);
      if (player != null) {
        player.setAlive(true);
      }
    }
    if (poisonTarget != null) {
      final poisonEvent = WitchPoisonEvent(target: poisonTarget);
      state.handleEvent(poisonEvent);
      await observer?.onGameEvent(poisonEvent);
      final player = state.getPlayerByName(poisonTarget.name);
      if (player != null) {
        player.setAlive(false);
      }
    }
    if (guardTarget != null) {
      final guardEvent = GuardProtectEvent(target: guardTarget);
      state.handleEvent(guardEvent);
      await observer?.onGameEvent(guardEvent);
      final player = state.getPlayerByName(guardTarget.name);
      if (player != null) {
        player.setProtected(true);
        player.setAlive(true);
      }
    }
    if (shootTarget != null) {
      final hunterEvent = HunterShootEvent(target: shootTarget);
      state.handleEvent(hunterEvent);
      await observer?.onGameEvent(hunterEvent);
      final player = state.getPlayerByName(shootTarget.name);
      if (player != null) {
        player.setAlive(false);
      }
    }
    final deadPlayers = lastAlivePlayers
        .where((player) => !player.isAlive)
        .toList();
    if (deadPlayers.isEmpty) {
      var judgeAnnouncementEvent = JudgeAnnouncementEvent(
        announcement: '昨晚是平安夜',
      );
      GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
      state.handleEvent(judgeAnnouncementEvent);
      await observer?.onGameEvent(judgeAnnouncementEvent);
    } else {
      for (var player in deadPlayers) {
        final deadEvent = DeadEvent(victim: player);
        state.handleEvent(deadEvent);
        await observer?.onGameEvent(deadEvent);
      }
      var judgeAnnouncementEvent = JudgeAnnouncementEvent(
        announcement:
            '昨晚${deadPlayers.map((player) => player.formattedName).join('、')}死亡',
      );
      GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
      state.handleEvent(judgeAnnouncementEvent);
      await observer?.onGameEvent(judgeAnnouncementEvent);
    }
    var judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '天亮了');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
  }

  GamePlayer? _getTargetGamePlayer(GameState state, List<String?> names) {
    if (names.isEmpty) return null;
    var map = <String, int>{};
    for (var name in names) {
      if (name == null) continue;
      map[name] = (map[name] ?? 0) + 1;
    }
    if (map.isEmpty) return null;
    var targetPlayerName = map.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    return state.getPlayerByName(targetPlayerName);
  }

  Future<GamePlayer?> _processHunterKill(
    GameState state, {
    GameObserver? observer,
  }) async {
    var judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '猎人请睁眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    final hunter = state.alivePlayers
        .where((player) => player.role is HunterRole)
        .first;
    // TODO
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '猎人请闭眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    return null;
  }

  Future<GamePlayer?> _processGuardProtect(
    GameState state, {
    GameObserver? observer,
  }) async {
    var judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '守卫请睁眼');
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
    final result = await guard.cast(
      guard.role.skills.whereType<ProtectSkill>().first,
      state,
    );
    final target = state.getPlayerByName(result.target ?? '');
    if (target != null) {
      final protectEvent = GuardProtectEvent(target: target);
      state.handleEvent(protectEvent);
      await observer?.onGameEvent(protectEvent);
      judgeAnnouncementEvent = JudgeAnnouncementEvent(
        announcement: '守卫对${target.formattedName}使用了保护',
      );
      GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
      state.handleEvent(judgeAnnouncementEvent);
    }
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '守卫请闭眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    return target;
  }

  Future<void> _processSeerInvestigate(
    GameState state, {
    GameObserver? observer,
  }) async {
    var judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '预言家请睁眼');
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
    final result = await seer.cast(
      seer.role.skills.whereType<InvestigateSkill>().first,
      state,
    );
    final target = state.getPlayerByName(result.target ?? '');
    if (target != null) {
      final investigateEvent = SeerInvestigateEvent(
        target: target,
        investigationResult: target.role.name,
      );
      state.handleEvent(investigateEvent);
      await observer?.onGameEvent(investigateEvent);
      judgeAnnouncementEvent = JudgeAnnouncementEvent(
        announcement: '${target.formattedName}是${target.role.name}',
      );
      GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
      state.handleEvent(judgeAnnouncementEvent);
    }
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '预言家请闭眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
  }

  Future<void> _processWerewolfDiscussion(
    GameState state, {
    GameObserver? observer,
  }) async {
    var judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '狼人请睁眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    final werewolves = state.alivePlayers
        .where((player) => player.role.isWerewolf)
        .toList();
    for (final werewolf in werewolves) {
      var result = await werewolf.cast(
        werewolf.role.skills.whereType<WerewolfDiscussSkill>().first,
        state,
      );
      var werewolfDiscussionEvent = WerewolfDiscussionEvent(
        speaker: werewolf,
        message: result.message ?? '',
      );
      state.handleEvent(werewolfDiscussionEvent);
      await observer?.onGameEvent(werewolfDiscussionEvent);
    }
  }

  Future<GamePlayer?> _processWerewolfKill(
    GameState state, {
    GameObserver? observer,
  }) async {
    var judgeAnnouncementEvent = JudgeAnnouncementEvent(
      announcement: '请选择你们要击杀的玩家',
    );
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    final werewolves = state.alivePlayers
        .where((player) => player.role.isWerewolf)
        .toList();
    List<Future<SkillResult>> futures = [];
    for (final werewolf in werewolves) {
      var future = werewolf.cast(
        werewolf.role.skills.whereType<KillSkill>().first,
        state,
      );
      futures.add(future);
    }
    var results = await Future.wait(futures);
    final names = results.map((result) => result.target).toList();
    var target = _getTargetGamePlayer(state, names);
    if (target == null) return null;
    var werewolfKillEvent = WerewolfKillEvent(target: target);
    state.handleEvent(werewolfKillEvent);
    await observer?.onGameEvent(werewolfKillEvent);
    judgeAnnouncementEvent = JudgeAnnouncementEvent(
      announcement: '狼人选择击杀${target.formattedName}',
    );
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '狼人请闭眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    return target;
  }

  Future<GamePlayer?> _processWitchHeal(
    GameState state, {
    GameObserver? observer,
  }) async {
    var judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '女巫请睁眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    final witch = state.alivePlayers
        .where((player) => player.role is WitchRole)
        .first;
    judgeAnnouncementEvent = JudgeAnnouncementEvent(
      announcement: '你有一瓶解药，你要用吗',
    );
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    final result = await witch.cast(
      witch.role.skills.whereType<HealSkill>().first,
      state,
    );
    final target = state.getPlayerByName(result.target ?? '');
    if (target != null) {
      final healEvent = WitchHealEvent(target: target);
      state.handleEvent(healEvent);
      await observer?.onGameEvent(healEvent);
      judgeAnnouncementEvent = JudgeAnnouncementEvent(
        announcement: '女巫对${target.formattedName}使用解药',
      );
      GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
      state.handleEvent(judgeAnnouncementEvent);
    }
    return target;
  }

  Future<GamePlayer?> _processWitchPoison(
    GameState state, {
    GameObserver? observer,
  }) async {
    var judgeAnnouncementEvent = JudgeAnnouncementEvent(
      announcement: '你有一瓶毒药，你要用吗',
    );
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    final witch = state.alivePlayers
        .where((player) => player.role is WitchRole)
        .first;
    final result = await witch.cast(
      witch.role.skills.whereType<PoisonSkill>().first,
      state,
    );
    final target = state.getPlayerByName(result.target ?? '');
    if (target != null) {
      final poisonEvent = WitchPoisonEvent(target: target);
      state.handleEvent(poisonEvent);
      await observer?.onGameEvent(poisonEvent);
      judgeAnnouncementEvent = JudgeAnnouncementEvent(
        announcement: '女巫对${target.formattedName}使用毒药',
      );
      GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
      state.handleEvent(judgeAnnouncementEvent);
    }
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '女巫请闭眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    return target;
  }
}
