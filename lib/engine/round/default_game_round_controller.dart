import 'dart:math';

import 'package:werewolf_arena/engine/event/system_event.dart';
import 'package:werewolf_arena/engine/event/peaceful_night_event.dart';
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
import 'package:werewolf_arena/engine/event/sheriff_campaign_event.dart';
import 'package:werewolf_arena/engine/event/sheriff_speech_event.dart';
import 'package:werewolf_arena/engine/event/sheriff_withdraw_event.dart';
import 'package:werewolf_arena/engine/event/sheriff_vote_event.dart';
import 'package:werewolf_arena/engine/event/sheriff_elected_event.dart';
import 'package:werewolf_arena/engine/event/sheriff_badge_transfer_event.dart';
import 'package:werewolf_arena/engine/event/sheriff_torn_event.dart';
import 'package:werewolf_arena/engine/game.dart';
import 'package:werewolf_arena/engine/game_logger.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/round/game_round_controller.dart';
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
import 'package:werewolf_arena/engine/skill/campaign_skill.dart';
import 'package:werewolf_arena/engine/skill/sheriff_speech_skill.dart';
import 'package:werewolf_arena/engine/skill/withdraw_skill.dart';
import 'package:werewolf_arena/engine/skill/sheriff_vote_skill.dart';
import 'package:werewolf_arena/engine/skill/transfer_badge_skill.dart';

/// 默认阶段处理器（基于技能系统重构）
class DefaultGameRoundController implements GameRoundController {
  @override
  Future<void> tick(Game game, {GameObserver? observer}) async {
    // 夜晚开始
    var systemEvent = SystemEvent('天黑请闭眼');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);
    await Future.delayed(const Duration(seconds: 1));
    // 守卫守护
    final protectTarget = await _processProtect(game, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 狼人讨论战术
    await _processConspire(game, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 狼人杀人
    final killTarget = await _processKill(game, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 预言家查验
    await _processInvestigate(game, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 女巫救人
    final healTarget = await _processHeal(game, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 女巫下毒
    final poisonTarget = await _processPoison(game, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 夜晚结算
    final lastNightDeadPlayers = await _processNightSettlement(
      game,
      observer: observer,
      killTarget: killTarget,
      healTarget: healTarget,
      poisonTarget: poisonTarget,
      guardTarget: protectTarget,
    );

    // 如果游戏在夜晚阶段结束，不执行后续白天阶段
    if (game.winner != null) {
      return;
    }

    await Future.delayed(const Duration(seconds: 1));
    // 公开讨论
    await _processDiscuss(
      game,
      observer: observer,
      lastNightDeadPlayers: lastNightDeadPlayers,
    );

    // 第一天：警长竞选流程
    if (game.day == 1) {
      await Future.delayed(const Duration(seconds: 1));
      await _processSheriffElection(game, observer: observer);
    }

    await Future.delayed(const Duration(seconds: 1));
    // 投票
    var voteTarget = await _processVote(game, observer: observer);
    await Future.delayed(const Duration(seconds: 1));
    // 遗言
    if (voteTarget != null) {
      await _processTestament(game, observer: observer, voteTarget: voteTarget);
      await Future.delayed(const Duration(seconds: 1));

      // 检查是否是警长死亡，如果是则触发警徽传递
      if (voteTarget.isSheriff) {
        await _processTransferBadge(game, observer: observer, deadSheriff: voteTarget);
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    // 检查被投票出局的玩家是否是猎人，如果是则触发开枪
    if (voteTarget?.role is HunterRole) {
      await Future.delayed(const Duration(seconds: 1));
      await _processShoot(
        game,
        observer: observer,
        hunter: voteTarget!,
        canShoot: true, // 白天投票出局的猎人可以开枪
      );
    }
    await Future.delayed(const Duration(seconds: 1));
    // 白天结算 - 检查游戏是否结束
    await _processDaySettlement(game, observer: observer);

    // 如果游戏在白天阶段结束，不执行后续操作
    if (game.winner != null) {
      return;
    }

    await Future.delayed(const Duration(seconds: 1));
    game.day++;
  }

  /// 生成白天发言顺序
  /// 规则：
  /// 1. 如果昨晚有人死亡，以死亡玩家位置为锚点，从其下一个存活玩家开始（随机选择顺序或逆序）
  /// 2. 如果是平安夜或第一天，随机选择一个存活玩家开始
  /// 3. 死亡玩家不在发言列表中
  List<GamePlayer> _generateSpeakOrder(
    Game game,
    List<GamePlayer> lastNightDeadPlayers,
  ) {
    final alivePlayers = game.alivePlayers;
    if (alivePlayers.isEmpty) return [];

    final random = Random();
    final allPlayers = game.players;
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

  GamePlayer? _getTargetGamePlayer(Game game, List<String?> names) {
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
    return game.getPlayerByName(targetPlayerName);
  }

  Future<void> _processConspire(Game game, {GameObserver? observer}) async {
    var systemEvent = SystemEvent('狼人请睁眼');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);
    final werewolves = game.alivePlayers
        .where((player) => player.role is WerewolfRole)
        .toList();
    for (final werewolf in werewolves) {
      final context = game.buildContextForPlayer(werewolf);
      var result = await werewolf.cast(
        werewolf.role.skills.whereType<ConspireSkill>().first,
        context,
      );
      var conspireEvent = ConspireEvent(
        result.message ?? '',
        source: werewolf,
        day: game.day,
      );
      game.handleEvent(conspireEvent);
      await observer?.onGameEvent(conspireEvent);
    }
  }

  /// 白天结算 - 处理投票出局后的游戏状态检查
  Future<void> _processDaySettlement(
    Game game, {
    GameObserver? observer,
  }) async {
    // 检查游戏是否结束
    if (game.checkGameEnd()) {
      GameLogger.instance.i('游戏在白天阶段结束');
    }
  }

  Future<void> _processDiscuss(
    Game game, {
    GameObserver? observer,
    required List<GamePlayer> lastNightDeadPlayers,
  }) async {
    var systemEvent = SystemEvent('所有人请睁眼');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);

    // 生成发言顺序
    final speakOrder = _generateSpeakOrder(game, lastNightDeadPlayers);

    var orderEvent = OrderEvent(day: game.day, players: speakOrder);
    GameLogger.instance.d(orderEvent.toString());
    game.handleEvent(orderEvent);
    await observer?.onGameEvent(orderEvent);

    for (var player in speakOrder) {
      final context = game.buildContextForPlayer(player);
      var result = await player.cast(
        player.role.skills.whereType<DiscussSkill>().first,
        context,
      );
      var discussEvent = DiscussEvent(
        result.message ?? '',
        source: player,
        day: game.day,
      );
      game.handleEvent(discussEvent);
      await observer?.onGameEvent(discussEvent);
    }
  }

  Future<GamePlayer?> _processHeal(Game game, {GameObserver? observer}) async {
    var systemEvent = SystemEvent('女巫请睁眼');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);
    systemEvent = SystemEvent('你有一瓶解药，你要用吗');
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);

    // 检查女巫是否还能使用解药
    if (!game.canUserHeal) return null;

    final witch = game.alivePlayers
        .where((player) => player.role is WitchRole)
        .firstOrNull;
    if (witch == null) return null;

    final context = game.buildContextForPlayer(witch);
    final result = await witch.cast(
      witch.role.skills.whereType<HealSkill>().first,
      context,
    );
    final target = game.getPlayerByName(result.target ?? '');

    // 女巫不能救自己 - 如果目标是女巫自己，忽略这次救人
    if (target != null && target.name != witch.name) {
      final healEvent = HealEvent(target: target, day: game.day);
      game.handleEvent(healEvent);
      await observer?.onGameEvent(healEvent);
      game.canUserHeal = false;
      systemEvent = SystemEvent('女巫对${target.formattedName}使用解药');
      GameLogger.instance.d(systemEvent.toString());
      game.handleEvent(systemEvent);
      return target;
    } else if (target != null && target.name == witch.name) {
      // 女巫试图救自己，记录日志但不执行
      GameLogger.instance.d('女巫不能救自己，解药使用失败');
      systemEvent = SystemEvent('女巫试图救自己，但规则不允许');
      GameLogger.instance.d(systemEvent.toString());
      game.handleEvent(systemEvent);
    }

    return null;
  }

  Future<void> _processInvestigate(Game game, {GameObserver? observer}) async {
    var systemEvent = SystemEvent('预言家请睁眼');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);
    systemEvent = SystemEvent('你要查验的玩家是谁');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);
    final seer = game.alivePlayers
        .where((player) => player.role is SeerRole)
        .firstOrNull;
    if (seer == null) return;
    final context = game.buildContextForPlayer(seer);
    final result = await seer.cast(
      seer.role.skills.whereType<InvestigateSkill>().first,
      context,
    );
    final target = game.getPlayerByName(result.target ?? '');
    if (target != null) {
      final investigateEvent = InvestigateEvent(target: target, day: game.day);
      game.handleEvent(investigateEvent);
      await observer?.onGameEvent(investigateEvent);
    }
    systemEvent = SystemEvent('预言家请闭眼');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);
  }

  Future<GamePlayer?> _processKill(Game game, {GameObserver? observer}) async {
    var systemEvent = SystemEvent('请选择你们要击杀的玩家');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);
    final werewolves = game.alivePlayers
        .where((player) => player.role is WerewolfRole)
        .toList();
    List<Future<SkillResult>> futures = [];
    for (final werewolf in werewolves) {
      final context = game.buildContextForPlayer(werewolf);
      var future = werewolf.cast(
        werewolf.role.skills.whereType<KillSkill>().first,
        context,
      );
      futures.add(future);
    }
    var results = await Future.wait(futures);
    final names = results.map((result) => result.target).toList();
    var target = _getTargetGamePlayer(game, names);
    if (target == null) return null;
    var werewolfKillEvent = KillEvent(target: target, day: game.day);
    game.handleEvent(werewolfKillEvent);
    await observer?.onGameEvent(werewolfKillEvent);
    if (target.role.id == 'witch') {
      game.canUserHeal = false;
    }
    systemEvent = SystemEvent('狼人请闭眼');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);
    return target;
  }

  Future<List<GamePlayer>> _processNightSettlement(
    Game game, {
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
        GameLogger.instance.d('${killTarget.formattedName}被守卫保护，免于狼人击杀');
      } else if (wasHealed) {
        GameLogger.instance.d('${killTarget.formattedName}被女巫解药救活');
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
      var peacefulNightEvent = PeacefulNightEvent();
      GameLogger.instance.d(peacefulNightEvent.toString());
      game.handleEvent(peacefulNightEvent);
      await observer?.onGameEvent(peacefulNightEvent);
    } else {
      for (var player in deadPlayers) {
        final deadEvent = DeadEvent(target: player, day: game.day);
        game.handleEvent(deadEvent);
        await observer?.onGameEvent(deadEvent);
      }
      var systemEvent = SystemEvent(
        '昨晚${deadPlayers.map((player) => player.name).join('、')}死亡',
      );
      GameLogger.instance.d(systemEvent.toString());
      game.handleEvent(systemEvent);
      await observer?.onGameEvent(systemEvent);
    }
    var systemEvent = SystemEvent('天亮了');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);

    // 检查是否有猎人死亡，如果有则触发开枪（夜晚死亡没有遗言）
    for (var player in deadPlayers) {
      if (player.role is HunterRole) {
        // 判断猎人是否可以开枪（被毒死不能开枪）
        final wasPoisoned =
            poisonTarget != null && poisonTarget.name == player.name;
        await Future.delayed(const Duration(seconds: 1));
        await _processShoot(
          game,
          observer: observer,
          hunter: player,
          canShoot: !wasPoisoned,
        );
      }
    }

    // 检查是否有警长死亡，如果有则触发警徽传递（夜晚死亡也要传递警徽）
    for (var player in deadPlayers) {
      if (player.isSheriff) {
        await Future.delayed(const Duration(seconds: 1));
        await _processTransferBadge(game, observer: observer, deadSheriff: player);
      }
    }

    // 检查游戏是否结束
    if (game.checkGameEnd()) {
      GameLogger.instance.i('游戏在夜晚阶段结束');
      return deadPlayers; // 游戏已结束，立即返回，不执行后续白天阶段
    }

    return deadPlayers;
  }

  Future<GamePlayer?> _processPoison(
    Game game, {
    GameObserver? observer,
  }) async {
    var systemEvent = SystemEvent('你有一瓶毒药，你要用吗');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);
    if (!game.canUserPoison) return null;
    final witch = game.alivePlayers
        .where((player) => player.role is WitchRole)
        .firstOrNull;
    if (witch == null) return null;
    final context = game.buildContextForPlayer(witch);
    final result = await witch.cast(
      witch.role.skills.whereType<PoisonSkill>().first,
      context,
    );
    final target = game.getPlayerByName(result.target ?? '');
    if (target != null) {
      final poisonEvent = PoisonEvent(target: target, day: game.day);
      game.handleEvent(poisonEvent);
      await observer?.onGameEvent(poisonEvent);
      game.canUserPoison = false;
      systemEvent = SystemEvent('女巫对${target.formattedName}使用毒药');
      GameLogger.instance.d(systemEvent.toString());
      game.handleEvent(systemEvent);
    }
    systemEvent = SystemEvent('女巫请闭眼');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);
    return target;
  }

  Future<GamePlayer?> _processProtect(
    Game game, {
    GameObserver? observer,
  }) async {
    var systemEvent = SystemEvent('守卫请睁眼');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);
    systemEvent = SystemEvent('你要守护的玩家是谁');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);

    final guard = game.alivePlayers
        .where((player) => player.role is GuardRole)
        .firstOrNull;
    if (guard == null) return null;

    final context = game.buildContextForPlayer(guard);
    final result = await guard.cast(
      guard.role.skills.whereType<ProtectSkill>().first,
      context,
    );
    final target = game.getPlayerByName(result.target ?? '');

    // 检查是否违反了"不能连续两次保护同一人"的规则
    if (target != null && game.lastProtectedPlayer == target.name) {
      // 守卫试图连续保护同一人，规则不允许
      GameLogger.instance.d('守卫不能连续两次保护${target.formattedName}，保护失败');
      systemEvent = SystemEvent('守卫试图连续保护${target.formattedName}，但规则不允许');
      GameLogger.instance.d(systemEvent.toString());
      game.handleEvent(systemEvent);
      systemEvent = SystemEvent('守卫请闭眼');
      GameLogger.instance.d(systemEvent.toString());
      game.handleEvent(systemEvent);
      await observer?.onGameEvent(systemEvent);
      return null;
    }

    if (target != null) {
      // 更新上一次守护的玩家
      game.lastProtectedPlayer = target.name;

      final protectEvent = ProtectEvent(target: target, day: game.day);
      game.handleEvent(protectEvent);
      await observer?.onGameEvent(protectEvent);
    }

    systemEvent = SystemEvent('守卫请闭眼');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);
    return target;
  }

  Future<GamePlayer?> _processShoot(
    Game game, {
    GameObserver? observer,
    required GamePlayer hunter,
    required bool canShoot,
  }) async {
    // 检查猎人是否可以开枪（被毒死不能开枪）
    if (!canShoot) return null;
    final context = game.buildContextForPlayer(hunter);
    final result = await hunter.cast(
      hunter.role.skills.whereType<ShootSkill>().first,
      context,
    );
    final target = game.getPlayerByName(result.target ?? '');

    if (target != null) {
      final shootEvent = ShootEvent(target: target, day: game.day);
      game.handleEvent(shootEvent);
      await observer?.onGameEvent(shootEvent);

      // 立即执行击杀
      target.setAlive(false);
      final deadEvent = DeadEvent(target: target, day: game.day);
      game.handleEvent(deadEvent);
      await observer?.onGameEvent(deadEvent);
      await Future.delayed(const Duration(seconds: 1));
      var systemEvent = SystemEvent('猎人对${target.name}开枪');
      GameLogger.instance.d(systemEvent.toString());
      game.handleEvent(systemEvent);
      await observer?.onGameEvent(systemEvent);
    }
    return target;
  }

  Future<void> _processTestament(
    Game game, {
    GameObserver? observer,
    required GamePlayer voteTarget,
  }) async {
    var systemEvent = SystemEvent('${voteTarget.name}请发表遗言');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);

    final context = game.buildContextForPlayer(voteTarget);
    var testamentResult = await voteTarget.cast(TestamentSkill(), context);
    var testamentEvent = TestamentEvent(
      testamentResult.message ?? '',
      source: voteTarget,
      day: game.day,
    );
    game.handleEvent(testamentEvent);
    await observer?.onGameEvent(testamentEvent);
  }

  Future<GamePlayer?> _processVote(Game game, {GameObserver? observer}) async {
    var systemEvent = SystemEvent('所有玩家讨论结束，开始投票');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);
    List<Future<SkillResult>> futures = [];
    for (var player in game.alivePlayers) {
      final context = game.buildContextForPlayer(player);
      futures.add(
        player.cast(player.role.skills.whereType<VoteSkill>().first, context),
      );
    }
    var results = await Future.wait(futures);
    for (var result in results) {
      if (result.target == null) continue;
      final voter = game.getPlayerByName(result.caster);
      final candidate = game.getPlayerByName(result.target!);
      if (voter == null || candidate == null) continue;
      var voteEvent = VoteEvent(
        voter: voter,
        candidate: candidate,
        day: game.day,
      );
      game.handleEvent(voteEvent);
      await observer?.onGameEvent(voteEvent);
    }

    // 使用警长权重计算得票数
    final voteCount = <String, double>{};
    for (var result in results) {
      if (result.target == null) continue;
      final voter = game.getPlayerByName(result.caster);
      if (voter == null) continue;

      final weight = voter.voteWeight; // 警长1.5票，普通玩家1.0票
      voteCount[result.target!] = (voteCount[result.target!] ?? 0.0) + weight;
    }

    // 找出得票最高的玩家
    if (voteCount.isEmpty) return null;

    final maxVotes = voteCount.values.reduce((a, b) => a > b ? a : b);
    final topCandidates = voteCount.entries.where((e) => e.value == maxVotes).toList();

    String? targetPlayerName;
    if (topCandidates.length == 1) {
      targetPlayerName = topCandidates.first.key;
    } else {
      // 平票情况，随机选择一个（或者可以选择流局，这里简化为随机）
      targetPlayerName = topCandidates[Random().nextInt(topCandidates.length)].key;
    }

    final targetPlayer = game.getPlayerByName(targetPlayerName);

    // 设置玩家出局并发送 ExileEvent
    if (targetPlayer != null) {
      targetPlayer.setAlive(false);
      var exileEvent = ExileEvent(day: game.day, target: targetPlayer);
      game.handleEvent(exileEvent);
      await observer?.onGameEvent(exileEvent);
    }

    return targetPlayer;
  }

  /// 警长竞选流程（仅第一天执行）
  /// 包括：上警 -> 竞选演讲 -> 退水 -> 投票选警
  Future<void> _processSheriffElection(
    Game game, {
    GameObserver? observer,
  }) async {
    var systemEvent = SystemEvent('开始警长竞选');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);

    // 阶段1: 上警阶段
    final candidates = await _processCampaign(game, observer: observer);

    if (candidates.isEmpty) {
      systemEvent = SystemEvent('无人上警，本局无警长');
      GameLogger.instance.d(systemEvent.toString());
      game.handleEvent(systemEvent);
      await observer?.onGameEvent(systemEvent);
      return;
    }

    if (candidates.length == 1) {
      // 只有一人上警，直接当选
      final sheriff = candidates.first;
      sheriff.isSheriff = true;
      game.sheriff = sheriff;
      game.badgeHistory.add(sheriff.name);

      final electedEvent = SheriffElectedEvent(
        sheriffName: sheriff.name,
        voteResults: {sheriff.name: 0},
        day: game.day,
      );
      game.handleEvent(electedEvent);
      await observer?.onGameEvent(electedEvent);

      systemEvent = SystemEvent('${sheriff.name}直接当选警长');
      GameLogger.instance.d(systemEvent.toString());
      game.handleEvent(systemEvent);
      await observer?.onGameEvent(systemEvent);
      return;
    }

    await Future.delayed(const Duration(seconds: 1));

    // 阶段2: 竞选演讲
    await _processSheriffSpeeches(game, observer: observer, candidates: candidates);

    await Future.delayed(const Duration(seconds: 1));

    // 阶段3: 退水环节
    final finalCandidates = await _processWithdraw(game, observer: observer, candidates: candidates);

    if (finalCandidates.isEmpty) {
      systemEvent = SystemEvent('所有候选人均已退水，本局无警长');
      GameLogger.instance.d(systemEvent.toString());
      game.handleEvent(systemEvent);
      await observer?.onGameEvent(systemEvent);
      return;
    }

    if (finalCandidates.length == 1) {
      // 只剩一人，直接当选
      final sheriff = finalCandidates.first;
      sheriff.isSheriff = true;
      game.sheriff = sheriff;
      game.badgeHistory.add(sheriff.name);

      final electedEvent = SheriffElectedEvent(
        sheriffName: sheriff.name,
        voteResults: {sheriff.name: 0},
        day: game.day,
      );
      game.handleEvent(electedEvent);
      await observer?.onGameEvent(electedEvent);

      systemEvent = SystemEvent('${sheriff.name}当选警长');
      GameLogger.instance.d(systemEvent.toString());
      game.handleEvent(systemEvent);
      await observer?.onGameEvent(systemEvent);
      return;
    }

    await Future.delayed(const Duration(seconds: 1));

    // 阶段4: 投票选警
    await _processSheriffVote(game, observer: observer, candidates: finalCandidates);
  }

  /// 上警阶段 - 玩家决定是否参加警长竞选
  Future<List<GamePlayer>> _processCampaign(
    Game game, {
    GameObserver? observer,
  }) async {
    var systemEvent = SystemEvent('请选择是否上警');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);

    final candidates = <GamePlayer>[];

    for (var player in game.alivePlayers) {
      final context = game.buildContextForPlayer(player);
      final result = await player.cast(CampaignSkill(), context);

      // 解析结果判断是否上警
      final decision = result.message?.trim() ?? '';
      final isCampaigning = decision.contains('上警') && !decision.contains('不上警');

      final campaignEvent = SheriffCampaignEvent(
        playerName: player.name,
        isCampaigning: isCampaigning,
        day: game.day,
      );
      game.handleEvent(campaignEvent);
      await observer?.onGameEvent(campaignEvent);

      if (isCampaigning) {
        candidates.add(player);
      }
    }

    systemEvent = SystemEvent(
      candidates.isEmpty
          ? '无人上警'
          : '上警玩家：${candidates.map((p) => p.name).join('、')}',
    );
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);

    return candidates;
  }

  /// 竞选演讲阶段 - 上警玩家发表竞选宣言
  Future<void> _processSheriffSpeeches(
    Game game, {
    GameObserver? observer,
    required List<GamePlayer> candidates,
  }) async {
    var systemEvent = SystemEvent('竞选发言阶段');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);

    for (var candidate in candidates) {
      final context = game.buildContextForPlayer(candidate);
      final result = await candidate.cast(SheriffSpeechSkill(), context);

      final speechEvent = SheriffSpeechEvent(
        playerName: candidate.name,
        speech: result.message ?? '',
        day: game.day,
      );
      game.handleEvent(speechEvent);
      await observer?.onGameEvent(speechEvent);
    }
  }

  /// 退水阶段 - 上警玩家可以选择退出竞选
  Future<List<GamePlayer>> _processWithdraw(
    Game game, {
    GameObserver? observer,
    required List<GamePlayer> candidates,
  }) async {
    var systemEvent = SystemEvent('退水环节');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);

    final finalCandidates = <GamePlayer>[];

    for (var candidate in candidates) {
      final context = game.buildContextForPlayer(candidate);
      final result = await candidate.cast(WithdrawSkill(), context);

      // 解析结果判断是否退水
      final decision = result.message?.trim() ?? '';
      final isWithdrawing = decision.contains('退水') && !decision.contains('不退水');

      if (isWithdrawing) {
        final withdrawEvent = SheriffWithdrawEvent(
          playerName: candidate.name,
          day: game.day,
        );
        game.handleEvent(withdrawEvent);
        await observer?.onGameEvent(withdrawEvent);
      } else {
        finalCandidates.add(candidate);
      }
    }

    if (finalCandidates.isNotEmpty) {
      systemEvent = SystemEvent(
        '最终候选人：${finalCandidates.map((p) => p.name).join('、')}',
      );
      GameLogger.instance.d(systemEvent.toString());
      game.handleEvent(systemEvent);
      await observer?.onGameEvent(systemEvent);
    }

    return finalCandidates;
  }

  /// 警长投票阶段 - 所有玩家投票选举警长
  Future<void> _processSheriffVote(
    Game game, {
    GameObserver? observer,
    required List<GamePlayer> candidates,
  }) async {
    var systemEvent = SystemEvent('开始投票选举警长');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);

    final voteCount = <String, int>{};
    for (var candidate in candidates) {
      voteCount[candidate.name] = 0;
    }

    // 所有存活玩家投票
    for (var voter in game.alivePlayers) {
      final context = game.buildContextForPlayer(voter);
      final result = await voter.cast(SheriffVoteSkill(), context);

      final targetName = result.target;
      if (targetName != null && voteCount.containsKey(targetName)) {
        voteCount[targetName] = (voteCount[targetName] ?? 0) + 1;

        final voteEvent = SheriffVoteEvent(
          voterName: voter.name,
          targetName: targetName,
          day: game.day,
        );
        game.handleEvent(voteEvent);
        await observer?.onGameEvent(voteEvent);
      }
    }

    // 统计得票最高者
    final maxVotes = voteCount.values.isEmpty ? 0 : voteCount.values.reduce((a, b) => a > b ? a : b);
    final winners = voteCount.entries.where((e) => e.value == maxVotes).toList();

    if (winners.length > 1) {
      // 平票，流局
      final electedEvent = SheriffElectedEvent(
        sheriffName: null,
        voteResults: voteCount,
        isRunoff: true,
        day: game.day,
      );
      game.handleEvent(electedEvent);
      await observer?.onGameEvent(electedEvent);

      systemEvent = SystemEvent('警长竞选平票流局，本局无警长');
      GameLogger.instance.d(systemEvent.toString());
      game.handleEvent(systemEvent);
      await observer?.onGameEvent(systemEvent);
    } else {
      // 选出警长
      final sheriffName = winners.first.key;
      final sheriff = game.getPlayerByName(sheriffName);

      if (sheriff != null) {
        sheriff.isSheriff = true;
        game.sheriff = sheriff;
        game.badgeHistory.add(sheriff.name);

        final electedEvent = SheriffElectedEvent(
          sheriffName: sheriffName,
          voteResults: voteCount,
          day: game.day,
        );
        game.handleEvent(electedEvent);
        await observer?.onGameEvent(electedEvent);

        systemEvent = SystemEvent('$sheriffName 当选警长');
        GameLogger.instance.d(systemEvent.toString());
        game.handleEvent(systemEvent);
        await observer?.onGameEvent(systemEvent);
      }
    }
  }

  /// 警徽传递 - 警长死亡时传递警徽或撕毁警徽
  Future<void> _processTransferBadge(
    Game game, {
    GameObserver? observer,
    required GamePlayer deadSheriff,
  }) async {
    var systemEvent = SystemEvent('${deadSheriff.name}是警长，请选择是否传递警徽');
    GameLogger.instance.d(systemEvent.toString());
    game.handleEvent(systemEvent);
    await observer?.onGameEvent(systemEvent);

    final context = game.buildContextForPlayer(deadSheriff);
    final result = await deadSheriff.cast(TransferBadgeSkill(), context);

    final decision = result.message?.trim() ?? '';

    if (decision.contains('撕毁警徽')) {
      // 撕毁警徽
      deadSheriff.isSheriff = false;
      game.sheriff = null;

      final tornEvent = SheriffTornEvent(
        sheriffName: deadSheriff.name,
        day: game.day,
      );
      game.handleEvent(tornEvent);
      await observer?.onGameEvent(tornEvent);

      systemEvent = SystemEvent('${deadSheriff.name}撕毁警徽');
      GameLogger.instance.d(systemEvent.toString());
      game.handleEvent(systemEvent);
      await observer?.onGameEvent(systemEvent);
    } else {
      // 尝试解析传递目标
      final targetName = result.target;
      final target = targetName != null ? game.getPlayerByName(targetName) : null;

      if (target != null && target.isAlive) {
        // 传递警徽
        deadSheriff.isSheriff = false;
        target.isSheriff = true;
        game.sheriff = target;
        game.badgeHistory.add(target.name);

        final transferEvent = SheriffBadgeTransferEvent(
          fromPlayerName: deadSheriff.name,
          toPlayerName: target.name,
          day: game.day,
        );
        game.handleEvent(transferEvent);
        await observer?.onGameEvent(transferEvent);

        systemEvent = SystemEvent('${deadSheriff.name}将警徽传给${target.name}');
        GameLogger.instance.d(systemEvent.toString());
        game.handleEvent(systemEvent);
        await observer?.onGameEvent(systemEvent);
      } else {
        // 无效的传递目标，视为撕毁警徽
        deadSheriff.isSheriff = false;
        game.sheriff = null;

        systemEvent = SystemEvent('警徽传递目标无效，警徽被撕毁');
        GameLogger.instance.d(systemEvent.toString());
        game.handleEvent(systemEvent);
        await observer?.onGameEvent(systemEvent);
      }
    }
  }
}
