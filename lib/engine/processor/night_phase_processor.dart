import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/role/guard_role.dart';
import 'package:werewolf_arena/engine/role/hunter_role.dart';
import 'package:werewolf_arena/engine/role/seer_role.dart';
import 'package:werewolf_arena/engine/role/werewolf_role.dart';
import 'package:werewolf_arena/engine/role/witch_role.dart';
import 'package:werewolf_arena/engine/game_phase.dart';
import 'package:werewolf_arena/engine/event/dead_event.dart';
import 'package:werewolf_arena/engine/event/protect_event.dart';
import 'package:werewolf_arena/engine/event/judge_announcement_event.dart';
import 'package:werewolf_arena/engine/event/investigate_event.dart';
import 'package:werewolf_arena/engine/event/conspire_event.dart';
import 'package:werewolf_arena/engine/event/kill_event.dart';
import 'package:werewolf_arena/engine/event/heal_event.dart';
import 'package:werewolf_arena/engine/event/poison_event.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skill/heal_skill.dart';
import 'package:werewolf_arena/engine/skill/investigate_skill.dart';
import 'package:werewolf_arena/engine/skill/kill_skill.dart';
import 'package:werewolf_arena/engine/skill/poison_skill.dart';
import 'package:werewolf_arena/engine/skill/protect_skill.dart';
import 'package:werewolf_arena/engine/skill/skill_result.dart';
import 'package:werewolf_arena/engine/skill/conspire_skill.dart';

import 'game_processor.dart';

/// 夜晚阶段处理器（基于技能系统重构）
///
/// 负责处理游戏中的夜晚阶段，通过技能系统统一处理所有夜晚行动
class NightPhaseProcessor implements GameProcessor {
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
    final protectTarget = await _processGuardProtect(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 猎人杀人
    final shootTarget = await _processHunterShoot(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 夜晚结算
    await _processNightSettlement(
      state,
      observer: observer,
      killTarget: killTarget,
      healTarget: healTarget,
      poisonTarget: poisonTarget,
      guardTarget: protectTarget,
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
    final deadPlayers = <GamePlayer>[];

    // 2. 狼人击杀（会被守卫保护阻止）
    if (killTarget != null) {
      // 只有未被守卫保护的玩家才会死亡
      final wasHealed =
          healTarget != null && healTarget.name == killTarget.name;
      if (!wasHealed) {
        // 未被女巫救，确认死亡
        killTarget.setAlive(false);
        deadPlayers.add(killTarget);
      }
    } else if (killTarget != null) {
      // 被守卫保护，击杀无效
      GameEngineLogger.instance.d('${killTarget.formattedName}被守卫保护，免于狼人击杀');
    }

    // 3. 女巫毒药（独立击杀）
    if (poisonTarget != null) {
      poisonTarget.setAlive(false);
      if (!deadPlayers.contains(poisonTarget)) {
        deadPlayers.add(poisonTarget);
      }
    }

    // 4. 猎人开枪（如果有的话）
    if (shootTarget != null) {
      shootTarget.setAlive(false);
      if (!deadPlayers.contains(shootTarget)) {
        deadPlayers.add(shootTarget);
      }
    }

    // 发布死亡公告
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

  Future<GamePlayer?> _processHunterShoot(
    GameState state, {
    GameObserver? observer,
  }) async {
    var judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '猎人请睁眼');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    final hunter = state.alivePlayers
        .where((player) => player.role is HunterRole)
        .firstOrNull;
    if (hunter == null) return null;
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
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '你要守护的玩家是谁');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);

    final guard = state.alivePlayers
        .where((player) => player.role is GuardRole)
        .firstOrNull;
    if (guard == null) return null;

    final result = await guard.cast(
      guard.role.skills.whereType<ProtectSkill>().first,
      state,
    );
    final target = state.getPlayerByName(result.target ?? '');

    // 检查是否违反了"不能连续两次保护同一人"的规则
    if (target != null) {
      // 守卫试图连续保护同一人，规则不允许
      GameEngineLogger.instance.d('守卫不能连续两次保护${target.formattedName}，保护失败');
      judgeAnnouncementEvent = JudgeAnnouncementEvent(
        announcement: '守卫试图连续保护${target.formattedName}，但规则不允许',
      );
      GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
      state.handleEvent(judgeAnnouncementEvent);
      judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '守卫请闭眼');
      GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
      state.handleEvent(judgeAnnouncementEvent);
      await observer?.onGameEvent(judgeAnnouncementEvent);
      return null;
    }

    if (target != null) {
      final protectEvent = ProtectEvent(target: target);
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
    judgeAnnouncementEvent = JudgeAnnouncementEvent(announcement: '你要查验的玩家是谁');
    GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);
    final seer = state.alivePlayers
        .where((player) => player.role is SeerRole)
        .firstOrNull;
    if (seer == null) return;
    final result = await seer.cast(
      seer.role.skills.whereType<InvestigateSkill>().first,
      state,
    );
    final target = state.getPlayerByName(result.target ?? '');
    if (target != null) {
      final investigateEvent = InvestigateEvent(
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
        .where((player) => player.role is WerewolfRole)
        .toList();
    for (final werewolf in werewolves) {
      var result = await werewolf.cast(
        werewolf.role.skills.whereType<ConspireSkill>().first,
        state,
      );
      var werewolfDiscussionEvent = ConspireEvent(
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
        .where((player) => player.role is WerewolfRole)
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
    var werewolfKillEvent = KillEvent(target: target);
    state.handleEvent(werewolfKillEvent);
    await observer?.onGameEvent(werewolfKillEvent);
    if (target.role.id == 'witch') {
      state.canUserHeal = false;
    }
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
    judgeAnnouncementEvent = JudgeAnnouncementEvent(
      announcement: '你有一瓶解药，你要用吗',
    );
    state.handleEvent(judgeAnnouncementEvent);
    await observer?.onGameEvent(judgeAnnouncementEvent);

    // 检查女巫是否还能使用解药
    if (!state.canUserHeal) return null;

    final witch = state.alivePlayers
        .where((player) => player.role is WitchRole)
        .firstOrNull;
    if (witch == null) return null;

    final result = await witch.cast(
      witch.role.skills.whereType<HealSkill>().first,
      state,
    );
    final target = state.getPlayerByName(result.target ?? '');

    // 女巫不能救自己 - 如果目标是女巫自己，忽略这次救人
    if (target != null && target.name != witch.name) {
      final healEvent = HealEvent(target: target);
      state.handleEvent(healEvent);
      await observer?.onGameEvent(healEvent);
      state.canUserHeal = false;
      judgeAnnouncementEvent = JudgeAnnouncementEvent(
        announcement: '女巫对${target.formattedName}使用解药',
      );
      GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
      state.handleEvent(judgeAnnouncementEvent);
      return target;
    } else if (target != null && target.name == witch.name) {
      // 女巫试图救自己，记录日志但不执行
      GameEngineLogger.instance.d('女巫不能救自己，解药使用失败');
      judgeAnnouncementEvent = JudgeAnnouncementEvent(
        announcement: '女巫试图救自己，但规则不允许',
      );
      GameEngineLogger.instance.d(judgeAnnouncementEvent.toString());
      state.handleEvent(judgeAnnouncementEvent);
    }

    return null;
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
    if (!state.canUserPoison) return null;
    final witch = state.alivePlayers
        .where((player) => player.role is WitchRole)
        .firstOrNull;
    if (witch == null) return null;
    final result = await witch.cast(
      witch.role.skills.whereType<PoisonSkill>().first,
      state,
    );
    final target = state.getPlayerByName(result.target ?? '');
    if (target != null) {
      final poisonEvent = PoisonEvent(target: target);
      state.handleEvent(poisonEvent);
      await observer?.onGameEvent(poisonEvent);
      state.canUserPoison = false;
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
