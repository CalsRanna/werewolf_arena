import 'dart:async';
import 'game_state.dart';
import 'game_action.dart';
import '../player/player.dart';
import '../player/role.dart';
import '../utils/game_logger.dart';
import '../utils/config_loader.dart';
import '../utils/random_helper.dart';

/// 游戏引擎 - 负责管理整个游戏流程
class GameEngine {
  GameEngine({
    required this.config,
    GameLogger? logger,
    RandomHelper? random,
  })  : logger = logger ?? GameLogger(config.loggingConfig),
        random = random ?? RandomHelper();
  final GameConfig config;
  final GameLogger logger;
  final RandomHelper random;

  GameState? _currentState;
  GameStatus _status = GameStatus.waiting;

  // Event controllers
  final StreamController<GameEvent> _eventController =
      StreamController<GameEvent>.broadcast();
  final StreamController<GameState> _stateController =
      StreamController<GameState>.broadcast();

  // Getters
  GameState? get currentState => _currentState;
  GameStatus get status => _status;
  bool get hasGameStarted => _currentState != null;
  bool get isGameRunning => hasGameStarted && _status == GameStatus.playing;
  bool get isGameEnded => hasGameStarted && _status == GameStatus.ended;

  // Streams
  Stream<GameEvent> get eventStream => _eventController.stream;
  Stream<GameState> get stateStream => _stateController.stream;

  /// 初始化游戏
  Future<void> initializeGame() async {
    logger.info('正在初始化游戏...');

    try {
      // Create initial game state (players must be set separately)
      _currentState = GameState(
        gameId: 'game_${DateTime.now().millisecondsSinceEpoch}',
        config: config,
        players: [], // Will be set by setPlayers method
      );

      logger.configLoaded('default_config.yaml');
      logger.info('游戏引擎已初始化，等待玩家设置');

      _stateController.add(_currentState!);
      _status = GameStatus.waiting;
    } catch (e) {
      logger.error('游戏初始化失败：$e');
      rethrow;
    }
  }

  /// 设置玩家列表
  void setPlayers(List<Player> players) {
    if (_currentState == null) {
      throw Exception('游戏状态未初始化');
    }

    _currentState!.players = players;
    logger.info('玩家已设置，数量：${players.length}');

    // Notify listeners of the update
    _stateController.add(_currentState!);
  }

  /// 开始游戏
  Future<void> startGame() async {
    if (!hasGameStarted) {
      await initializeGame();
    }

    if (isGameRunning) {
      logger.warning('游戏已经在运行中');
      return;
    }

    logger.info('正在开始游戏...');
    _status = GameStatus.playing;
    _currentState!.startGame();

    // 创建游戏日志
    logger.startNewGame(_currentState!.gameId);

    // 法官宣布游戏开始
    _currentState!.judge.announceGameStart(_currentState!.players.length);

    logger.gameStart(_currentState!.gameId, _currentState!.players.length);
    _stateController.add(_currentState!);
    _eventController.add(_currentState!.eventHistory.last);

    // Don't start game loop automatically - it should be controlled by UI
    // The game loop will be started by the main application
  }

  /// 执行一个游戏步骤（由UI控制）
  Future<void> executeGameStep() async {
    if (!isGameRunning || isGameEnded) return;

    try {
      await _processGamePhase();

      // Check game end condition
      if (_currentState!.checkGameEnd()) {
        await _endGame();
      }
    } catch (e) {
      logger.error('游戏步骤执行出错：$e');
      await _handleGameError(e);
    }
  }

  /// 游戏主循环
  Future<void> _runGameLoop() async {
    logger.info('游戏主循环已开始');

    while (!isGameEnded && isGameRunning) {
      try {
        await _processGamePhase();

        // Check game end condition
        if (_currentState!.checkGameEnd()) {
          await _endGame();
          break;
        }

        // Small delay to prevent overwhelming
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        logger.error('游戏循环出错：$e');
        await _handleGameError(e);
      }
    }

    logger.info('游戏主循环已结束');
  }

  /// 处理游戏阶段
  Future<void> _processGamePhase() async {
    final state = _currentState!;

    switch (state.currentPhase) {
      case GamePhase.night:
        await _processNightPhase();
        break;
      case GamePhase.day:
        await _processDayPhase();
        break;
      case GamePhase.voting:
        await _processVotingPhase();
        break;
      case GamePhase.ended:
        // Game should end, but check just in case
        if (!isGameEnded) {
          await _endGame();
        }
        break;
    }
  }

  /// 处理夜晚阶段
  Future<void> _processNightPhase() async {
    final state = _currentState!;

    logger.phaseChange('night', state.dayNumber);

    // 法官宣布夜晚开始
    state.judge.announceNightStart(state.dayNumber);

    // Clear night actions
    state.clearNightActions();

    // Process night actions in CORRECT ORDER - one role at a time
    await processWerewolfActions();
    await processGuardActions();
    await processSeerActions();
    await processWitchActions();

    // Resolve night actions
    await resolveNightActions();

    // Move to day phase
    state.changePhase(GamePhase.day);
    _stateController.add(state);
  }

  /// 获取玩家行动顺序
  List<Player> _getActionOrder(List<Player> players) {
    if (config.actionOrder.isSequential) {
      // 按玩家名称中的数字排序 (例如 "1号玩家", "2号玩家")
      final sortedPlayers = List<Player>.from(players);
      sortedPlayers.sort((a, b) {
        // 提取玩家名称中的数字
        final aNum =
            int.tryParse(a.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final bNum =
            int.tryParse(b.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return aNum.compareTo(bNum);
      });

      return config.actionOrder.isReverse
          ? sortedPlayers.reversed.toList()
          : sortedPlayers;
    } else {
      // 随机顺序（保持原有逻辑）
      return players;
    }
  }

  /// 处理狼人行动 - 如果有多个狼人，他们需要协商（公共方法）
  Future<void> processWerewolfActions() async {
    final state = _currentState!;
    final werewolves =
        state.alivePlayers.where((p) => p.role.isWerewolf).toList();

    if (werewolves.isEmpty) return;

    logger.info('正在处理狼人行动...');

    if (werewolves.length == 1) {
      // Single werewolf decides alone
      final werewolf = werewolves.first;
      if (werewolf is AIPlayer && werewolf.isAlive) {
        logger.info('${werewolf.name} 正在选择击杀目标...');
        try {
          await werewolf.processInformation(state);
          final action = await werewolf.chooseAction(state);
          if (action is KillAction &&
              action.target != null &&
              action.target!.isAlive &&
              werewolf.canPerformAction(action, state)) {
            state.setTonightVictim(action.target!);
            logger.info('狼人选择了受害者：${action.target!.name}');
          } else {
            logger.info('狼人没有选择有效的击杀目标');
          }
        } catch (e) {
          logger.error('狼人 ${werewolf.name} 行动失败: $e');
        }
      }
    } else {
      // Multiple werewolves vote on target sequentially
      final victims = <Player, int>{};

      for (int i = 0; i < werewolves.length; i++) {
        final werewolf = werewolves[i];
        if (werewolf is AIPlayer && werewolf.isAlive) {
          logger.info('${werewolf.name} 正在选择击杀目标...');
          try {
            await werewolf.processInformation(state);
            final action = await werewolf.chooseAction(state);
            if (action is KillAction &&
                action.target != null &&
                action.target!.isAlive &&
                werewolf.canPerformAction(action, state)) {
              victims[action.target!] = (victims[action.target!] ?? 0) + 1;
              logger.info('${werewolf.name} 选择击杀 ${action.target!.name}');
            } else {
              logger.info('${werewolf.name} 没有做出有效选择');
            }
          } catch (e) {
            logger.error('狼人 ${werewolf.name} 行动失败: $e');
          }

          // Delay between werewolf actions
          if (i < werewolves.length - 1) {
            await Future.delayed(const Duration(milliseconds: 1000));
          }
        }
      }

      // Select victim with most votes
      if (victims.isNotEmpty) {
        final victim =
            victims.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        state.setTonightVictim(victim);
        logger.info('狼人最终选择了受害者：${victim.name}');
      } else {
        logger.info('狼人没有选择任何目标');
      }
    }
  }

  /// 处理守卫行动 - 每个守卫依次行动（公共方法）
  Future<void> processGuardActions() async {
    final state = _currentState!;
    final guards =
        state.alivePlayers.where((p) => p.role is GuardRole).toList();

    if (guards.isEmpty) return;

    logger.info('正在处理守卫行动...');

    // Each guard acts in turn
    for (int i = 0; i < guards.length; i++) {
      final guard = guards[i];
      if (guard is AIPlayer && guard.isAlive) {
        logger.info('${guard.name} 正在选择守护目标...');
        try {
          await guard.processInformation(state);
          final action = await guard.chooseAction(state);
          if (action is ProtectAction &&
              action.target?.isAlive == true &&
              guard.canPerformAction(action, state)) {
            guard.performAction(action, state);
            logger.info('${guard.name} 守护了 ${action.target?.name}');
          } else {
            logger.info('${guard.name} 没有做出有效的守护选择');
          }
        } catch (e) {
          logger.error('守卫 ${guard.name} 行动失败: $e');
        }

        // Delay between guard actions
        if (i < guards.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
    }
  }

  /// 处理预言家行动 - 每个预言家依次行动（公共方法）
  Future<void> processSeerActions() async {
    final state = _currentState!;
    final seers = state.alivePlayers.where((p) => p.role is SeerRole).toList();

    if (seers.isEmpty) return;

    logger.info('正在处理预言家行动...');

    // Each seer acts in turn
    for (int i = 0; i < seers.length; i++) {
      final seer = seers[i];
      if (seer is AIPlayer && seer.isAlive) {
        logger.info('${seer.name} 正在选择查验目标...');
        try {
          await seer.processInformation(state);
          final action = await seer.chooseAction(state);
          if (action is InvestigateAction &&
              action.target?.isAlive == true &&
              seer.canPerformAction(action, state)) {
            seer.performAction(action, state);
            logger.info('${seer.name} 查验了 ${action.target?.name}');
          } else {
            logger.info('${seer.name} 没有做出有效的查验选择');
          }
        } catch (e) {
          logger.error('预言家 ${seer.name} 行动失败: $e');
        }

        // Delay between seer actions
        if (i < seers.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
    }
  }

  /// 处理女巫行动 - 每个女巫依次行动（公共方法）
  Future<void> processWitchActions() async {
    final state = _currentState!;
    final witches =
        state.alivePlayers.where((p) => p.role is WitchRole).toList();

    if (witches.isEmpty) return;

    logger.info('正在处理女巫行动...');

    // Each witch acts in turn
    for (int i = 0; i < witches.length; i++) {
      final witch = witches[i];
      if (witch is AIPlayer && witch.role is WitchRole && witch.isAlive) {
        final witchRole = witch.role as WitchRole;

        // Set tonight victim for witch decision
        witchRole.setTonightVictim(state.tonightVictim);

        logger.info('${witch.name} 正在考虑是否用药...');

        try {
          await witch.processInformation(state);
          final action = await witch.chooseAction(state);

          if (action != null && witch.canPerformAction(action, state)) {
            // 检查毒药目标是否存活
            if (action is PoisonAction && action.target?.isAlive != true) {
              logger.info('${witch.name} 毒药目标无效（目标已死亡）');
            } else {
              witch.performAction(action, state);
              if (action is HealAction) {
                logger.info('${witch.name} 使用了解药');
              } else if (action is PoisonAction) {
                logger.info('${witch.name} 使用了毒药毒杀 ${action.target?.name}');
              }
            }
          } else {
            logger.info('${witch.name} 选择不使用药剂或动作无效');
          }
        } catch (e) {
          logger.error('女巫 ${witch.name} 行动失败: $e');
          logger.info('${witch.name} 由于错误选择不使用药剂');
        }

        // Delay between witch actions
        if (i < witches.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
    }
  }

  /// 解决夜晚行动结果（公共方法）
  Future<void> resolveNightActions() async {
    final state = _currentState!;

    logger.info('正在结算夜晚行动...');

    final Player? victim = state.tonightVictim;
    final protected = state.tonightProtected;
    final poisoned = state.tonightPoisoned;

    // Process kill (cancelled if protected or healed)
    if (victim != null && !state.killCancelled && victim != protected) {
      victim.die('被狼人击杀', state);
      logger.playerDeath(victim.playerId, 'werewolf_kill');
    }

    // Process poison
    if (poisoned != null && poisoned != protected) {
      poisoned.die('被毒杀', state);
      logger.playerDeath(poisoned.playerId, 'witch_poison');
    }

    // Clear night action data
    state.clearNightActions();

    // Reduce skill cooldowns
    for (final player in state.alivePlayers) {
      player.reduceSkillCooldowns();
    }
  }

  /// 处理白天阶段
  Future<void> _processDayPhase() async {
    final state = _currentState!;
    logger.phaseChange('day', state.dayNumber);

    // Announce night results
    await _announceNightResults();

    // Discussion phase
    await runDiscussionPhase();

    // Move to voting phase
    state.changePhase(GamePhase.voting);
    _stateController.add(state);
  }

  /// 宣布夜晚结果
  Future<void> _announceNightResults() async {
    final state = _currentState!;
    final deathsTonight = state.eventHistory
        .where((e) => e.type == GameEventType.playerDeath)
        .toList();

    // 收集死亡信息
    final deathMessages = <String>[];
    if (deathsTonight.isEmpty) {
      deathMessages.add('平安夜，无人死亡');
    } else {
      for (final death in deathsTonight) {
        final victim = death.target;
        if (victim != null) {
          deathMessages.add('${victim.name} 死亡: ${death.description}');
        } else {
          deathMessages.add(death.description);
        }
      }
    }

    // 法官宣布白天开始和夜晚结果
    state.judge.announceDayStart(state.dayNumber, deathMessages);

    if (deathsTonight.isEmpty) {
      logger.info('平安夜，无人死亡');
    } else {
      for (final death in deathsTonight) {
        logger.info('${death.target?.name} 死亡: ${death.description}');
      }
    }
  }

  /// 运行讨论阶段 - 玩家按顺序发言（公共方法）
  Future<void> runDiscussionPhase() async {
    final state = _currentState!;
    final alivePlayers =
        _getActionOrder(state.alivePlayers.where((p) => p.isAlive).toList());

    logger.info('Starting discussion phase...');

    // 收集本轮讨论的发言历史
    final discussionHistory = <String>[];

    // AI players discuss in turn, one by one
    for (int i = 0; i < alivePlayers.length; i++) {
      final player = alivePlayers[i];

      // 双重检查：确保玩家仍然存活
      if (player is AIPlayer && player.isAlive) {
        try {
          // Ensure each step completes fully before proceeding
          await player.processInformation(state);

          // 构建包含讨论历史的上下文
          String context = '白天讨论阶段，请根据前面玩家的发言发表你的看法。';
          if (discussionHistory.isNotEmpty) {
            context += '\n\n前面玩家的发言：\n${discussionHistory.join('\n')}';
          }
          context += '\n\n现在轮到你发言，请针对当前局势和其他玩家的观点发表你的看法：';

          // Wait for statement generation to complete fully
          final statement = await player.generateStatement(state, context);

          if (statement.isNotEmpty) {
            final speakAction = SpeakAction(actor: player, message: statement);
            if (player.canPerformAction(speakAction, state)) {
              player.performAction(speakAction, state);

              // 记录发言到法官系统
              state.recordPlayerSpeech(player, statement);

              // 记录发言到回合日志
              logger.logPlayerSpeech(
                  player.name, player.role.name, statement, '白天讨论');

              // 在控制台显示清洁的发言格式
              print('[${player.name}][${player.role.name}]: $statement\n');

              // 将发言添加到讨论历史中
              discussionHistory.add('[${player.name}]: $statement');
            } else {
              logger.warning('${player.name} 无法在当前阶段发言');
            }
          } else {
            logger.info('${player.name} 没有发言');
          }
        } catch (e) {
          logger.error('玩家 ${player.name} 发言失败: $e');
          logger.info('${player.name} 由于错误跳过发言');
        }

        // Longer delay to ensure UI synchronization
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }

    logger.info('讨论阶段结束');
    // Wait for user confirmation to continue
    await waitForUserConfirmation('讨论结束，按回车键进入投票阶段...');
  }

  /// 处理投票阶段
  Future<void> _processVotingPhase() async {
    final state = _currentState!;
    logger.phaseChange('voting', state.dayNumber);

    // 法官宣布投票阶段
    state.judge.announceVotingPhase();

    // Clear previous votes
    state.clearVotes();

    // Collect votes
    await collectVotes();

    // Resolve voting
    await resolveVoting();

    // Move to next night
    state.dayNumber++;
    state.changePhase(GamePhase.night);
    _stateController.add(state);
  }

  /// 收集投票 - 玩家按顺序投票（公共方法）
  Future<void> collectVotes() async {
    final state = _currentState!;
    final alivePlayers =
        _getActionOrder(state.alivePlayers.where((p) => p.isAlive).toList());

    logger.info('正在收集投票...');

    // Each player votes in turn
    for (int i = 0; i < alivePlayers.length; i++) {
      final voter = alivePlayers[i];

      // 双重检查：确保玩家仍然存活且可以投票
      if (voter is AIPlayer && voter.isAlive) {
        logger.info('${voter.name} 正在投票...');
        try {
          // Ensure each step completes fully
          await voter.processInformation(state);
          final action = await voter.chooseAction(state);

          if (action is VoteAction &&
              action.target != null &&
              action.target!.isAlive &&
              voter.canPerformAction(action, state)) {
            voter.performAction(action, state);
            logger.info('${voter.name} 投票给 ${action.target!.name}');
          } else {
            logger.info('${voter.name} 弃票或动作无效');
          }

          // Mark completion before moving to next player
        } catch (e) {
          logger.error('玩家 ${voter.name} 投票失败: $e');
          logger.info('${voter.name} 由于错误弃票');
        }

        // Longer delay to ensure proper sequencing
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }

    logger.info(
        'Votes collected: ${state.totalVotes}/${state.alivePlayers.length}');
  }

  /// 解决投票结果（公共方法）
  Future<void> resolveVoting() async {
    final state = _currentState!;
    final voteTarget = state.getVoteTarget();
    final voteResults = state.getVoteResults();

    // 法官宣布投票结果
    state.judge.announceVotingResult(voteTarget?.name, voteResults);

    if (voteTarget != null) {
      // Execute player
      voteTarget.die('被投票处决', state);
      logger.playerDeath(voteTarget.playerId, 'vote_execution');

      // Handle hunter skill
      if (voteTarget.role is HunterRole && voteTarget.isDead) {
        await _handleHunterDeath(voteTarget);
      }
    } else {
      logger.info('没有玩家被处决（未达到多数票）');
    }

    state.clearVotes();
  }

  /// 处理猎人死亡
  Future<void> _handleHunterDeath(Player hunter) async {
    if (hunter.role is HunterRole) {
      final hunterRole = hunter.role as HunterRole;
      if (hunterRole.canShoot(_currentState!)) {
        logger.info('猎人可以开枪！');

        // Simple AI: shoot most suspicious player
        if (hunter is AIPlayer) {
          final state = _currentState!;
          final suspiciousPlayers = hunter.getMostSuspiciousPlayers(state);
          if (suspiciousPlayers.isNotEmpty) {
            final target = suspiciousPlayers.first;
            final shootAction =
                HunterShootAction(actor: hunter, target: target);
            hunter.performAction(shootAction, state);
          }
        }
      }
    }
  }

  /// 等待用户确认
  Future<void> waitForUserConfirmation(String message) async {
    // In console app, we'll use stdin for user input
    print(message);
    // TODO: Implement proper console input handling
  }

  /// 处理游戏错误 - 不停止游戏，记录错误并继续
  Future<void> _handleGameError(dynamic error) async {
    logger.error('游戏错误：$error');

    // Don't stop the game for individual player errors
    // Just log and continue
    logger.info('游戏继续运行，已记录错误');

    // Notify listeners of the error but don't change game status
    _eventController.add(GameEvent(
      eventId: 'error_${DateTime.now().millisecondsSinceEpoch}',
      type: GameEventType.playerAction,
      description: '游戏发生错误：$error',
      data: {'error': error.toString()},
    ));
  }

  /// 结束游戏
  Future<void> _endGame() async {
    if (_currentState == null) return;

    final state = _currentState!;
    final duration = DateTime.now().difference(state.startTime);

    _status = GameStatus.ended;
    state.endGame(state.winner ?? 'unknown');

    // 法官宣布游戏结束
    final playerRoles = <String, String>{};
    for (final player in state.players) {
      playerRoles[player.name] = player.role.name;
    }
    state.judge.announceGameEnd(state.winner ?? 'unknown', playerRoles);

    logger.gameEnd(
        state.gameId, state.winner ?? 'unknown', duration.inMilliseconds);
    logger.stats(
        'Game completed in ${state.dayNumber} days with ${state.players.length} players');

    _stateController.add(state);
    _eventController.add(state.eventHistory.last);
  }

  /// 暂停游戏
  void pauseGame() {
    if (isGameRunning) {
      _status = GameStatus.paused;
      logger.info('游戏已暂停');
    }
  }

  /// 恢复游戏
  void resumeGame() {
    if (_status == GameStatus.paused) {
      _status = GameStatus.playing;
      logger.info('游戏已恢复');
      unawaited(_runGameLoop());
    }
  }

  /// 停止游戏
  void stopGame() {
    _status = GameStatus.ended;
    logger.info('游戏已手动停止');

    if (_currentState != null) {
      _currentState!.endGame('手动停止');
    }
  }

  /// 获取游戏统计
  Map<String, dynamic> getGameStats() {
    if (_currentState == null) {
      return {'status': 'no_game'};
    }

    final state = _currentState!;
    return {
      'gameId': state.gameId,
      'status': _status.name,
      'currentPhase': state.currentPhase.name,
      'dayNumber': state.dayNumber,
      'playerCount': state.players.length,
      'alivePlayers': state.alivePlayers.length,
      'deadPlayers': state.deadPlayers.length,
      'winner': state.winner,
      'duration': state.lastUpdateTime != null
          ? state.lastUpdateTime!.difference(state.startTime).inMilliseconds
          : 0,
      'totalEvents': state.eventHistory.length,
      'werewolvesAlive': state.aliveWerewolves,
      'villagersAlive': state.aliveVillagers,
    };
  }

  /// 销毁游戏引擎
  void dispose() {
    _eventController.close();
    _stateController.close();
    logger.info('游戏引擎已销毁');
  }
}
