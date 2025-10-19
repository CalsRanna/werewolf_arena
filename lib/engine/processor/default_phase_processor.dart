import 'package:werewolf_arena/engine/event/announce_event.dart';
import 'package:werewolf_arena/engine/event/conspire_event.dart';
import 'package:werewolf_arena/engine/event/dead_event.dart';
import 'package:werewolf_arena/engine/event/discuss_event.dart';
import 'package:werewolf_arena/engine/event/heal_event.dart';
import 'package:werewolf_arena/engine/event/investigate_event.dart';
import 'package:werewolf_arena/engine/event/kill_event.dart';
import 'package:werewolf_arena/engine/event/order_event.dart';
import 'package:werewolf_arena/engine/event/poison_event.dart';
import 'package:werewolf_arena/engine/event/protect_event.dart';
import 'package:werewolf_arena/engine/event/vote_event.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/processor/game_processor.dart';
import 'package:werewolf_arena/engine/role/guard_role.dart';
import 'package:werewolf_arena/engine/role/hunter_role.dart';
import 'package:werewolf_arena/engine/role/seer_role.dart';
import 'package:werewolf_arena/engine/role/werewolf_role.dart';
import 'package:werewolf_arena/engine/role/witch_role.dart';
import 'package:werewolf_arena/engine/skill/conspire_skill.dart';
import 'package:werewolf_arena/engine/skill/discuss_skill.dart';
import 'package:werewolf_arena/engine/skill/heal_skill.dart';
import 'package:werewolf_arena/engine/skill/investigate_skill.dart';
import 'package:werewolf_arena/engine/skill/kill_skill.dart';
import 'package:werewolf_arena/engine/skill/poison_skill.dart';
import 'package:werewolf_arena/engine/skill/protect_skill.dart';
import 'package:werewolf_arena/engine/skill/skill_result.dart';
import 'package:werewolf_arena/engine/skill/vote_skill.dart';

/// 默认阶段处理器（基于技能系统重构）
class DefaultPhaseProcessor implements GameProcessor {
  @override
  Future<void> process(GameState state, {GameObserver? observer}) async {
    var announceEvent = AnnounceEvent('天黑请闭眼');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await Future.delayed(const Duration(seconds: 1));
    // 守卫守护
    final protectTarget = await _processProtect(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 狼人讨论战术
    await _processConspire(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 狼人杀人
    final killTarget = await _processKill(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 预言家查验
    await _processInvestigate(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 女巫救人
    final healTarget = await _processHeal(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 女巫下毒
    final poisonTarget = await _processPoison(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 猎人杀人
    final shootTarget = await _processShoot(state, observer: observer);
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
    announceEvent = AnnounceEvent('天亮了');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    await Future.delayed(const Duration(seconds: 1));
    // 公开讨论
    await _processDiscuss(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 投票
    await _processVote(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    state.dayNumber++;
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

  Future<void> _processConspire(
    GameState state, {
    GameObserver? observer,
  }) async {
    var announceEvent = AnnounceEvent('狼人请睁眼');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    final werewolves = state.alivePlayers
        .where((player) => player.role is WerewolfRole)
        .toList();
    for (final werewolf in werewolves) {
      var result = await werewolf.cast(
        werewolf.role.skills.whereType<ConspireSkill>().first,
        state,
      );
      var conspireEvent = ConspireEvent(
        speaker: werewolf,
        message: result.message ?? '',
      );
      state.handleEvent(conspireEvent);
      await observer?.onGameEvent(conspireEvent);
    }
  }

  Future<void> _processDiscuss(
    GameState state, {
    GameObserver? observer,
  }) async {
    var announceEvent = AnnounceEvent('所有人请睁眼');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    var orderEvent = OrderEvent(players: state.alivePlayers, direction: '顺序');
    GameEngineLogger.instance.d(orderEvent.toString());
    state.handleEvent(orderEvent);
    await observer?.onGameEvent(orderEvent);
    for (var player in state.alivePlayers) {
      var result = await player.cast(
        player.role.skills.whereType<DiscussSkill>().first,
        state,
      );
      var discussEvent = DiscussEvent(
        speaker: player,
        message: result.message ?? '',
      );
      state.handleEvent(discussEvent);
      await observer?.onGameEvent(discussEvent);
    }
  }

  Future<GamePlayer?> _processHeal(
    GameState state, {
    GameObserver? observer,
  }) async {
    var announceEvent = AnnounceEvent('女巫请睁眼');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    announceEvent = AnnounceEvent('你有一瓶解药，你要用吗');
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);

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
      announceEvent = AnnounceEvent('女巫对${target.formattedName}使用解药');
      GameEngineLogger.instance.d(announceEvent.toString());
      state.handleEvent(announceEvent);
      return target;
    } else if (target != null && target.name == witch.name) {
      // 女巫试图救自己，记录日志但不执行
      GameEngineLogger.instance.d('女巫不能救自己，解药使用失败');
      announceEvent = AnnounceEvent('女巫试图救自己，但规则不允许');
      GameEngineLogger.instance.d(announceEvent.toString());
      state.handleEvent(announceEvent);
    }

    return null;
  }

  Future<void> _processInvestigate(
    GameState state, {
    GameObserver? observer,
  }) async {
    var announceEvent = AnnounceEvent('预言家请睁眼');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    announceEvent = AnnounceEvent('你要查验的玩家是谁');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
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
      announceEvent = AnnounceEvent(
        '${target.formattedName}是${target.role.name}',
      );
      GameEngineLogger.instance.d(announceEvent.toString());
      state.handleEvent(announceEvent);
    }
    announceEvent = AnnounceEvent('预言家请闭眼');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
  }

  Future<GamePlayer?> _processKill(
    GameState state, {
    GameObserver? observer,
  }) async {
    var announceEvent = AnnounceEvent('请选择你们要击杀的玩家');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
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
    announceEvent = AnnounceEvent('狼人选择击杀${target.formattedName}');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    announceEvent = AnnounceEvent('狼人请闭眼');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    return target;
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

    // 2. 狼人击杀（会被守卫保护和女巫解药阻止）
    if (killTarget != null) {
      final wasProtected =
          guardTarget != null && guardTarget.name == killTarget.name;
      final wasHealed =
          healTarget != null && healTarget.name == killTarget.name;

      if (wasProtected) {
        // 被守卫保护，击杀无效
        GameEngineLogger.instance.d('${killTarget.formattedName}被守卫保护，免于狼人击杀');
      } else if (wasHealed) {
        // 被女巫救，免于死亡
        GameEngineLogger.instance.d('${killTarget.formattedName}被女巫解药救活');
      } else {
        // 未被保护也未被救，确认死亡
        killTarget.setAlive(false);
        deadPlayers.add(killTarget);
      }
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
      var announceEvent = AnnounceEvent('昨晚是平安夜');
      GameEngineLogger.instance.d(announceEvent.toString());
      state.handleEvent(announceEvent);
      await observer?.onGameEvent(announceEvent);
    } else {
      for (var player in deadPlayers) {
        final deadEvent = DeadEvent(victim: player);
        state.handleEvent(deadEvent);
        await observer?.onGameEvent(deadEvent);
      }
      var announceEvent = AnnounceEvent(
        '昨晚${deadPlayers.map((player) => player.formattedName).join('、')}死亡',
      );
      GameEngineLogger.instance.d(announceEvent.toString());
      state.handleEvent(announceEvent);
      await observer?.onGameEvent(announceEvent);
    }
    var announceEvent = AnnounceEvent('天亮了');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
  }

  Future<GamePlayer?> _processPoison(
    GameState state, {
    GameObserver? observer,
  }) async {
    var announceEvent = AnnounceEvent('你有一瓶毒药，你要用吗');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
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
      announceEvent = AnnounceEvent('女巫对${target.formattedName}使用毒药');
      GameEngineLogger.instance.d(announceEvent.toString());
      state.handleEvent(announceEvent);
    }
    announceEvent = AnnounceEvent('女巫请闭眼');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    return target;
  }

  Future<GamePlayer?> _processProtect(
    GameState state, {
    GameObserver? observer,
  }) async {
    var announceEvent = AnnounceEvent('守卫请睁眼');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    announceEvent = AnnounceEvent('你要守护的玩家是谁');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);

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
    if (target != null && state.lastProtectedPlayer == target.name) {
      // 守卫试图连续保护同一人，规则不允许
      GameEngineLogger.instance.d('守卫不能连续两次保护${target.formattedName}，保护失败');
      announceEvent = AnnounceEvent('守卫试图连续保护${target.formattedName}，但规则不允许');
      GameEngineLogger.instance.d(announceEvent.toString());
      state.handleEvent(announceEvent);
      announceEvent = AnnounceEvent('守卫请闭眼');
      GameEngineLogger.instance.d(announceEvent.toString());
      state.handleEvent(announceEvent);
      await observer?.onGameEvent(announceEvent);
      return null;
    }

    if (target != null) {
      // 更新上一次守护的玩家
      state.lastProtectedPlayer = target.name;

      final protectEvent = ProtectEvent(target: target);
      state.handleEvent(protectEvent);
      await observer?.onGameEvent(protectEvent);

      // 注意：不在这里公布守护结果，具体是否成功阻止击杀将在夜晚结算中判断
      GameEngineLogger.instance.d('守卫选择守护${target.formattedName}');
    }

    announceEvent = AnnounceEvent('守卫请闭眼');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    return target;
  }

  Future<GamePlayer?> _processShoot(
    GameState state, {
    GameObserver? observer,
  }) async {
    var announceEvent = AnnounceEvent('猎人请睁眼');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    final hunter = state.alivePlayers
        .where((player) => player.role is HunterRole)
        .firstOrNull;
    if (hunter == null) return null;
    // TODO
    announceEvent = AnnounceEvent('猎人请闭眼');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    return null;
  }

  Future<void> _processVote(GameState state, {GameObserver? observer}) async {
    var announceEvent = AnnounceEvent('所有玩家讨论结束，开始投票');
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    List<Future<SkillResult>> futures = [];
    for (var player in state.alivePlayers) {
      futures.add(
        player.cast(player.role.skills.whereType<VoteSkill>().first, state),
      );
    }
    var results = await Future.wait(futures);
    for (var result in results) {
      if (result.target == null) continue;
      var voteEvent = VoteEvent(
        voter: state.getPlayerByName(result.caster)!,
        candidate: state.getPlayerByName(result.target!)!,
      );
      state.handleEvent(voteEvent);
      await observer?.onGameEvent(voteEvent);
    }

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
  }
}
