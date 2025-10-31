import 'dart:math';

import 'package:werewolf_arena/engine/event/announce_event.dart';
import 'package:werewolf_arena/engine/event/conspire_event.dart';
import 'package:werewolf_arena/engine/event/dead_event.dart';
import 'package:werewolf_arena/engine/event/discuss_event.dart';
import 'package:werewolf_arena/engine/event/exile_event.dart';
import 'package:werewolf_arena/engine/event/heal_event.dart';
import 'package:werewolf_arena/engine/event/investigate_event.dart';
import 'package:werewolf_arena/engine/event/kill_event.dart';
import 'package:werewolf_arena/engine/event/order_event.dart';
import 'package:werewolf_arena/engine/event/poison_event.dart';
import 'package:werewolf_arena/engine/event/protect_event.dart';
import 'package:werewolf_arena/engine/event/shoot_event.dart';
import 'package:werewolf_arena/engine/event/testament_event.dart';
import 'package:werewolf_arena/engine/event/vote_event.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/game_round/game_round_controller.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/player/ai_player.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
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
import 'package:werewolf_arena/engine/skill/shoot_skill.dart';
import 'package:werewolf_arena/engine/skill/skill_result.dart';
import 'package:werewolf_arena/engine/skill/testament_skill.dart';
import 'package:werewolf_arena/engine/skill/vote_skill.dart';

/// 默认阶段处理器（基于技能系统重构）
class DefaultGameRoundController implements GameRoundController {
  @override
  Future<void> tick(GameState state, {GameObserver? observer}) async {
    // 记录当前回合开始前的事件数量
    final eventsCountBeforeRound = state.events.length;
    // 夜晚开始
    var announceEvent = AnnounceEvent('天黑请闭眼', day: state.day);
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
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
    // 夜晚结算
    final lastNightDeadPlayers = await _processNightSettlement(
      state,
      observer: observer,
      killTarget: killTarget,
      healTarget: healTarget,
      poisonTarget: poisonTarget,
      guardTarget: protectTarget,
    );
    await Future.delayed(const Duration(seconds: 1));
    // 公开讨论
    await _processDiscuss(
      state,
      observer: observer,
      lastNightDeadPlayers: lastNightDeadPlayers,
    );
    await Future.delayed(const Duration(seconds: 1));
    // 投票
    var voteTarget = await _processVote(state, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 遗言
    if (voteTarget != null) {
      await _processTestament(
        state,
        observer: observer,
        voteTarget: voteTarget,
      );
      await Future.delayed(const Duration(seconds: 1));
    }
    // 检查被投票出局的玩家是否是猎人，如果是则触发开枪
    if (voteTarget?.role is HunterRole) {
      await Future.delayed(const Duration(seconds: 1));
      await _processShoot(
        state,
        observer: observer,
        hunter: voteTarget!,
        canShoot: true, // 白天投票出局的猎人可以开枪
      );
    }
    await Future.delayed(const Duration(seconds: 1));
    // 白天结算 - 检查游戏是否结束
    await _processDaySettlement(state, observer: observer);

    // 更新所有活着玩家的记忆
    await _updateAIPlayerMemories(state, eventsCountBeforeRound);

    state.day++;
  }

  /// 生成白天发言顺序
  /// 规则：
  /// 1. 如果昨晚有人死亡，以死亡玩家位置为锚点，从其下一个存活玩家开始（随机选择顺序或逆序）
  /// 2. 如果是平安夜或第一天，随机选择一个存活玩家开始
  /// 3. 死亡玩家不在发言列表中
  List<GamePlayer> _generateSpeakOrder(
    GameState state,
    List<GamePlayer> lastNightDeadPlayers,
  ) {
    final alivePlayers = state.alivePlayers;
    if (alivePlayers.isEmpty) return [];

    final random = Random();
    final allPlayers = state.players;
    int startIndex;

    // 确定发言起点索引
    if (lastNightDeadPlayers.isNotEmpty) {
      // 如果昨晚有人死亡，以死亡玩家位置为锚点
      final deadPlayer = lastNightDeadPlayers.first;
      final anchorIndex = allPlayers.indexOf(deadPlayer);

      // 随机决定顺序或逆序
      final isClockwise = random.nextBool();

      // 从锚点的下一个位置开始（顺序或逆序）
      if (isClockwise) {
        startIndex = (anchorIndex + 1) % allPlayers.length;
      } else {
        startIndex = (anchorIndex - 1 + allPlayers.length) % allPlayers.length;
      }

      // 找到第一个存活玩家作为实际起点
      int attempts = 0;
      while (!allPlayers[startIndex].isAlive && attempts < allPlayers.length) {
        if (isClockwise) {
          startIndex = (startIndex + 1) % allPlayers.length;
        } else {
          startIndex = (startIndex - 1 + allPlayers.length) % allPlayers.length;
        }
        attempts++;
      }

      // 生成发言顺序
      final speakOrder = <GamePlayer>[];
      int currentIndex = startIndex;
      for (int i = 0; i < allPlayers.length; i++) {
        final player = allPlayers[currentIndex];
        if (player.isAlive) {
          speakOrder.add(player);
        }
        if (isClockwise) {
          currentIndex = (currentIndex + 1) % allPlayers.length;
        } else {
          currentIndex =
              (currentIndex - 1 + allPlayers.length) % allPlayers.length;
        }
      }

      return speakOrder;
    } else {
      // 平安夜或第一天，随机选择一个存活玩家作为起点
      final startPlayer = alivePlayers[random.nextInt(alivePlayers.length)];
      startIndex = allPlayers.indexOf(startPlayer);

      // 随机决定顺序或逆序
      final isClockwise = random.nextBool();

      // 生成发言顺序
      final speakOrder = <GamePlayer>[];
      int currentIndex = startIndex;
      for (int i = 0; i < allPlayers.length; i++) {
        final player = allPlayers[currentIndex];
        if (player.isAlive) {
          speakOrder.add(player);
        }
        if (isClockwise) {
          currentIndex = (currentIndex + 1) % allPlayers.length;
        } else {
          currentIndex =
              (currentIndex - 1 + allPlayers.length) % allPlayers.length;
        }
      }

      return speakOrder;
    }
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
    var announceEvent = AnnounceEvent('狼人请睁眼', day: state.day);
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
        result.message ?? '',
        source: werewolf,
        day: state.day,
      );
      state.handleEvent(conspireEvent);
      await observer?.onGameEvent(conspireEvent);
    }
  }

  /// 白天结算 - 处理投票出局后的游戏状态检查
  Future<void> _processDaySettlement(
    GameState state, {
    GameObserver? observer,
  }) async {
    // 检查游戏是否结束
    if (state.checkGameEnd()) {
      GameEngineLogger.instance.i('游戏在白天阶段结束');
    }
  }

  Future<void> _processDiscuss(
    GameState state, {
    GameObserver? observer,
    required List<GamePlayer> lastNightDeadPlayers,
  }) async {
    var announceEvent = AnnounceEvent('所有人请睁眼', day: state.day);
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);

    // 生成发言顺序
    final speakOrder = _generateSpeakOrder(state, lastNightDeadPlayers);

    var orderEvent = OrderEvent(day: state.day, players: speakOrder);
    GameEngineLogger.instance.d(orderEvent.toString());
    state.handleEvent(orderEvent);
    await observer?.onGameEvent(orderEvent);

    for (var player in speakOrder) {
      var result = await player.cast(
        player.role.skills.whereType<DiscussSkill>().first,
        state,
      );
      var discussEvent = DiscussEvent(
        result.message ?? '',
        source: player,
        day: state.day,
      );
      state.handleEvent(discussEvent);
      await observer?.onGameEvent(discussEvent);
    }
  }

  Future<GamePlayer?> _processHeal(
    GameState state, {
    GameObserver? observer,
  }) async {
    var announceEvent = AnnounceEvent('女巫请睁眼', day: state.day);
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    announceEvent = AnnounceEvent('你有一瓶解药，你要用吗', day: state.day);
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
      final healEvent = HealEvent(target: target, day: state.day);
      state.handleEvent(healEvent);
      await observer?.onGameEvent(healEvent);
      state.canUserHeal = false;
      announceEvent = AnnounceEvent(
        '女巫对${target.formattedName}使用解药',
        day: state.day,
      );
      GameEngineLogger.instance.d(announceEvent.toString());
      state.handleEvent(announceEvent);
      return target;
    } else if (target != null && target.name == witch.name) {
      // 女巫试图救自己，记录日志但不执行
      GameEngineLogger.instance.d('女巫不能救自己，解药使用失败');
      announceEvent = AnnounceEvent('女巫试图救自己，但规则不允许', day: state.day);
      GameEngineLogger.instance.d(announceEvent.toString());
      state.handleEvent(announceEvent);
    }

    return null;
  }

  Future<void> _processInvestigate(
    GameState state, {
    GameObserver? observer,
  }) async {
    var announceEvent = AnnounceEvent('预言家请睁眼', day: state.day);
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    announceEvent = AnnounceEvent('你要查验的玩家是谁', day: state.day);
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
      final investigateEvent = InvestigateEvent(target: target, day: state.day);
      state.handleEvent(investigateEvent);
      await observer?.onGameEvent(investigateEvent);
      announceEvent = AnnounceEvent(
        '${target.formattedName}是${target.role.name}',
        day: state.day,
      );
      GameEngineLogger.instance.d(announceEvent.toString());
      state.handleEvent(announceEvent);
    }
    announceEvent = AnnounceEvent('预言家请闭眼', day: state.day);
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
  }

  Future<GamePlayer?> _processKill(
    GameState state, {
    GameObserver? observer,
  }) async {
    var announceEvent = AnnounceEvent('请选择你们要击杀的玩家', day: state.day);
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
    var werewolfKillEvent = KillEvent(target: target, day: state.day);
    state.handleEvent(werewolfKillEvent);
    await observer?.onGameEvent(werewolfKillEvent);
    if (target.role.id == 'witch') {
      state.canUserHeal = false;
    }
    announceEvent = AnnounceEvent('狼人请闭眼', day: state.day);
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    return target;
  }

  Future<List<GamePlayer>> _processNightSettlement(
    GameState state, {
    GameObserver? observer,
    GamePlayer? killTarget,
    GamePlayer? healTarget,
    GamePlayer? poisonTarget,
    GamePlayer? guardTarget,
  }) async {
    final deadPlayers = <GamePlayer>[];
    if (killTarget != null) {
      final wasProtected =
          guardTarget != null && guardTarget.name == killTarget.name;
      final wasHealed =
          healTarget != null && healTarget.name == killTarget.name;
      if (wasProtected) {
        GameEngineLogger.instance.d('${killTarget.formattedName}被守卫保护，免于狼人击杀');
      } else if (wasHealed) {
        GameEngineLogger.instance.d('${killTarget.formattedName}被女巫解药救活');
      } else {
        killTarget.setAlive(false);
        deadPlayers.add(killTarget);
      }
    }
    if (poisonTarget != null) {
      poisonTarget.setAlive(false);
      if (!deadPlayers.contains(poisonTarget)) {
        deadPlayers.add(poisonTarget);
      }
    }

    // 发布死亡公告
    if (deadPlayers.isEmpty) {
      var announceEvent = AnnounceEvent('昨晚是平安夜', day: state.day);
      GameEngineLogger.instance.d(announceEvent.toString());
      state.handleEvent(announceEvent);
      await observer?.onGameEvent(announceEvent);
    } else {
      for (var player in deadPlayers) {
        final deadEvent = DeadEvent(target: player, day: state.day);
        state.handleEvent(deadEvent);
        await observer?.onGameEvent(deadEvent);
      }
      var announceEvent = AnnounceEvent(
        '昨晚${deadPlayers.map((player) => player.name).join('、')}死亡',
        day: state.day,
      );
      GameEngineLogger.instance.d(announceEvent.toString());
      state.handleEvent(announceEvent);
      await observer?.onGameEvent(announceEvent);
    }
    var announceEvent = AnnounceEvent('天亮了', day: state.day);
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);

    // 检查是否有猎人死亡，如果有则触发开枪
    for (var player in deadPlayers) {
      if (player.role is HunterRole) {
        // 判断猎人是否可以开枪（被毒死不能开枪）
        final wasPoisoned =
            poisonTarget != null && poisonTarget.name == player.name;
        await Future.delayed(const Duration(seconds: 1));
        await _processShoot(
          state,
          observer: observer,
          hunter: player,
          canShoot: !wasPoisoned,
        );
      }
    }

    // 检查游戏是否结束
    if (state.checkGameEnd()) {
      GameEngineLogger.instance.i('游戏在夜晚阶段结束');
    }

    return deadPlayers;
  }

  Future<GamePlayer?> _processPoison(
    GameState state, {
    GameObserver? observer,
  }) async {
    var announceEvent = AnnounceEvent('你有一瓶毒药，你要用吗', day: state.day);
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
      final poisonEvent = PoisonEvent(target: target, day: state.day);
      state.handleEvent(poisonEvent);
      await observer?.onGameEvent(poisonEvent);
      state.canUserPoison = false;
      announceEvent = AnnounceEvent(
        '女巫对${target.formattedName}使用毒药',
        day: state.day,
      );
      GameEngineLogger.instance.d(announceEvent.toString());
      state.handleEvent(announceEvent);
    }
    announceEvent = AnnounceEvent('女巫请闭眼', day: state.day);
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    return target;
  }

  Future<GamePlayer?> _processProtect(
    GameState state, {
    GameObserver? observer,
  }) async {
    var announceEvent = AnnounceEvent('守卫请睁眼', day: state.day);
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    announceEvent = AnnounceEvent('你要守护的玩家是谁', day: state.day);
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
      announceEvent = AnnounceEvent(
        '守卫试图连续保护${target.formattedName}，但规则不允许',
        day: state.day,
      );
      GameEngineLogger.instance.d(announceEvent.toString());
      state.handleEvent(announceEvent);
      announceEvent = AnnounceEvent('守卫请闭眼', day: state.day);
      GameEngineLogger.instance.d(announceEvent.toString());
      state.handleEvent(announceEvent);
      await observer?.onGameEvent(announceEvent);
      return null;
    }

    if (target != null) {
      // 更新上一次守护的玩家
      state.lastProtectedPlayer = target.name;

      final protectEvent = ProtectEvent(target: target, day: state.day);
      state.handleEvent(protectEvent);
      await observer?.onGameEvent(protectEvent);
    }

    announceEvent = AnnounceEvent('守卫请闭眼', day: state.day);
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);
    return target;
  }

  Future<GamePlayer?> _processShoot(
    GameState state, {
    GameObserver? observer,
    required GamePlayer hunter,
    required bool canShoot,
  }) async {
    // 检查猎人是否可以开枪（被毒死不能开枪）
    if (!canShoot) return null;
    final result = await hunter.cast(
      hunter.role.skills.whereType<ShootSkill>().first,
      state,
    );
    final target = state.getPlayerByName(result.target ?? '');

    if (target != null) {
      final shootEvent = ShootEvent(target: target, day: state.day);
      state.handleEvent(shootEvent);
      await observer?.onGameEvent(shootEvent);

      // 立即执行击杀
      target.setAlive(false);
      final deadEvent = DeadEvent(target: target, day: state.day);
      state.handleEvent(deadEvent);
      await observer?.onGameEvent(deadEvent);
      await Future.delayed(const Duration(seconds: 1));
      var announceEvent = AnnounceEvent('猎人对${target.name}开枪', day: state.day);
      GameEngineLogger.instance.d(announceEvent.toString());
      state.handleEvent(announceEvent);
      await observer?.onGameEvent(announceEvent);
    }
    return target;
  }

  Future<void> _processTestament(
    GameState state, {
    GameObserver? observer,
    required GamePlayer voteTarget,
  }) async {
    var announceEvent = AnnounceEvent(
      '${voteTarget.name}请发表遗言',
      day: state.day,
    );
    GameEngineLogger.instance.d(announceEvent.toString());
    state.handleEvent(announceEvent);
    await observer?.onGameEvent(announceEvent);

    var testamentResult = await voteTarget.cast(TestamentSkill(), state);
    var testamentEvent = TestamentEvent(
      testamentResult.message ?? '',
      source: voteTarget,
      day: state.day,
    );
    state.handleEvent(testamentEvent);
    await observer?.onGameEvent(testamentEvent);
  }

  Future<GamePlayer?> _processVote(
    GameState state, {
    GameObserver? observer,
  }) async {
    var announceEvent = AnnounceEvent('所有玩家讨论结束，开始投票', day: state.day);
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
      final voter = state.getPlayerByName(result.caster);
      final candidate = state.getPlayerByName(result.target!);
      if (voter == null || candidate == null) continue;
      var voteEvent = VoteEvent(
        voter: voter,
        candidate: candidate,
        day: state.day,
      );
      state.handleEvent(voteEvent);
      await observer?.onGameEvent(voteEvent);
    }
    final names = results.map((result) => result.target).toList();
    var targetPlayer = _getTargetGamePlayer(state, names);

    // 设置玩家出局并发送 ExileEvent
    if (targetPlayer != null) {
      targetPlayer.setAlive(false);
      var exileEvent = ExileEvent(day: state.day, target: targetPlayer);
      state.handleEvent(exileEvent);
      await observer?.onGameEvent(exileEvent);
    }

    return targetPlayer;
  }

  /// 更新AI玩家记忆
  ///
  /// 在回合结束时调用,为每个活着的AI玩家并行更新记忆
  Future<void> _updateAIPlayerMemories(
    GameState state,
    int eventsCountBeforeRound,
  ) async {
    final currentRoundEvents = state.events.sublist(eventsCountBeforeRound);
    final aliveAIPlayers = state.alivePlayers.whereType<AIPlayer>().toList();
    final futures = aliveAIPlayers.map((player) async {
      try {
        final updatedMemory = await player.driver.updateMemory(
          player: player,
          currentMemory: player.memory,
          currentRoundEvents: currentRoundEvents,
          state: state,
        );
        player.memory = updatedMemory;
      } catch (e) {
        GameEngineLogger.instance.e('更新${player.name}的记忆失败: $e');
      }
    }).toList();
    await Future.wait(futures);
  }
}
