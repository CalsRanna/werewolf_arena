import 'dart:async';
import 'game_state.dart';
import 'game_event.dart';
import '../player/player.dart';
import '../player/role.dart';
import '../llm/enhanced_prompts.dart';
import '../utils/logger_util.dart';
import '../utils/config_loader.dart';
import '../utils/random_helper.dart';
import '../utils/player_logger.dart';

/// Game engine - manages the entire game flow
class GameEngine {
  GameEngine({required this.config, RandomHelper? random})
      : random = random ?? RandomHelper();
  final GameConfig config;
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

  /// Initialize game
  Future<void> initializeGame() async {
    LoggerUtil.instance.i('Initializing game...');

    try {
      // Create initial game state (players must be set separately)
      _currentState = GameState(
        gameId: 'game_${DateTime.now().toString()}',
        config: config,
        players: [], // Will be set by setPlayers method
      );

      // Reinitialize LoggerUtil with gameId for game-specific logging
      LoggerUtil.instance.initialize(
        enableConsole: true,
        enableFile: true,
        useColors: true,
        logLevel: 'info',
        gameId: _currentState!.gameId,
      );

      // Initialize player logger for debugging (after LoggerUtil gameId is set)
      PlayerLogger.instance.initialize();

      LoggerUtil.instance.d('default_config.yaml');
      LoggerUtil.instance
          .i('Game engine initialized, waiting for player setup');

      _stateController.add(_currentState!);
      _status = GameStatus.waiting;
    } catch (e) {
      LoggerUtil.instance.e('Game initialization failed: $e');
      rethrow;
    }
  }

  /// Set player list
  void setPlayers(List<Player> players) {
    if (_currentState == null) {
      throw Exception('Game state not initialized');
    }

    _currentState!.players = players;

    // Notify listeners of the update
    _stateController.add(_currentState!);
  }

  /// Start game
  Future<void> startGame() async {
    if (!hasGameStarted) {
      await initializeGame();
    }

    if (isGameRunning) {
      LoggerUtil.instance.w('Game is already running');
      return;
    }

    LoggerUtil.instance.i('Starting game...');
    _status = GameStatus.playing;
    _currentState!.startGame();

    // Create game log
    LoggerUtil.instance.i(
      'Started new game: ${_currentState!.gameId} with ${_currentState!.players.length} players',
    );

    _stateController.add(_currentState!);
    _eventController.add(_currentState!.eventHistory.last);

    // Don't start game loop automatically - it should be controlled by UI
    // The game loop will be started by the main application
  }

  /// Execute one game step (controlled by UI)
  Future<void> executeGameStep() async {
    if (!isGameRunning || isGameEnded) return;

    try {
      await _processGamePhase();

      // Check game end condition
      if (_currentState!.checkGameEnd()) {
        await _endGame();
      }
    } catch (e) {
      LoggerUtil.instance.e('Game step execution error: $e');
      await _handleGameError(e);
    }
  }

  /// Main game loop
  Future<void> _runGameLoop() async {
    LoggerUtil.instance.i('Main game loop started');

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
        LoggerUtil.instance.e('Game loop error: $e');
        await _handleGameError(e);
      }
    }

    LoggerUtil.instance.i('Main game loop ended');
  }

  /// Process game phase
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

  /// Process night phase
  Future<void> _processNightPhase() async {
    final state = _currentState!;

    LoggerUtil.instance.i(
      'Phase changed to night, Day ${state.dayNumber}',
    );

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
    await state.changePhase(GamePhase.day);
    _stateController.add(state);
  }

  /// Get player action order based on last death/execution as starting point
  List<Player> _getActionOrder(List<Player> players) {
    if (players.isEmpty) return [];

    // Get all players sorted by their numbers for baseline ordering
    final allPlayersSorted = List<Player>.from(_currentState!.players);
    allPlayersSorted.sort((a, b) {
      final aNum = int.tryParse(a.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final bNum = int.tryParse(b.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return aNum.compareTo(bNum);
    });

    // Find the last player who died or was executed
    Player? lastDeadPlayer = _findLastDeadPlayer();

    if (lastDeadPlayer == null) {
      // No death reference point, use random selection
      final aliveIndices = <int>[];
      for (int i = 0; i < allPlayersSorted.length; i++) {
        if (allPlayersSorted[i].isAlive) {
          aliveIndices.add(i);
        }
      }

      if (aliveIndices.isEmpty) return [];

      // Randomly select starting point
      final randomIndex = aliveIndices[random.nextInt(aliveIndices.length)];
      final startingPlayer = allPlayersSorted[randomIndex];

      LoggerUtil.instance.i(
        '[法官]: 法官随机选择 ${startingPlayer.name} 作为发言起始点',
      );

      return _reorderFromStartingPoint(allPlayersSorted, players, randomIndex);
    }

    // Find the index of the last dead player in the sorted list
    final deadPlayerIndex = allPlayersSorted
        .indexWhere((p) => p.playerId == lastDeadPlayer.playerId);
    if (deadPlayerIndex == -1) {
      // Fallback to normal ordering if something goes wrong
      return _reorderFromStartingPoint(allPlayersSorted, players, 0);
    }

    // Determine starting point (next player after the dead one)
    int startingIndex = (deadPlayerIndex + 1) % allPlayersSorted.length;

    // Find the next alive player from that position
    for (int i = 0; i < allPlayersSorted.length; i++) {
      final currentIndex = (startingIndex + i) % allPlayersSorted.length;
      final currentPlayer = allPlayersSorted[currentIndex];
      if (currentPlayer.isAlive) {
        return _reorderFromStartingPoint(
            allPlayersSorted, players, currentIndex);
      }
    }

    // Should not reach here, but fallback just in case
    return _reorderFromStartingPoint(allPlayersSorted, players, 0);
  }

  /// Find the last player who died or was executed
  Player? _findLastDeadPlayer() {
    final state = _currentState!;

    // Look for the most recent death event (includes executions)
    final deathEvents = state.eventHistory
        .where((e) => e.type == GameEventType.playerDeath)
        .toList();

    if (deathEvents.isNotEmpty) {
      // Sort by timestamp and get the most recent
      deathEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final lastEvent = deathEvents.first;
      return lastEvent.target ?? lastEvent.initiator;
    }

    return null; // No deaths yet
  }

  /// Reorder players starting from a specific index
  List<Player> _reorderFromStartingPoint(List<Player> allPlayersSorted,
      List<Player> alivePlayers, int startingIndex) {
    final orderedPlayers = <Player>[];
    final alivePlayerIds = alivePlayers.map((p) => p.playerId).toSet();

    // Build order string for logging
    final orderNames = <String>[];
    final isReverse = RandomHelper().nextBool();
    if (isReverse) {
      // Reverse order
      for (int i = 0; i < allPlayersSorted.length; i++) {
        final currentIndex = (startingIndex - i + allPlayersSorted.length) %
            allPlayersSorted.length;
        final player = allPlayersSorted[currentIndex];
        if (alivePlayerIds.contains(player.playerId)) {
          orderedPlayers.add(player);
          orderNames.add(player.name);
        }
      }
    } else {
      // Forward order
      for (int i = 0; i < allPlayersSorted.length; i++) {
        final currentIndex = (startingIndex + i) % allPlayersSorted.length;
        final player = allPlayersSorted[currentIndex];
        if (alivePlayerIds.contains(player.playerId)) {
          orderedPlayers.add(player);
          orderNames.add(player.name);
        }
      }
    }

    // Log the speaking order
    final direction = isReverse ? "逆序" : "顺序";
    LoggerUtil.instance.i('[法官]: 从${orderNames.first}开始$direction发言');

    return orderedPlayers;
  }

  /// Process werewolf actions - if multiple werewolves, they need to negotiate (public method)
  Future<void> processWerewolfActions() async {
    final state = _currentState!;
    final werewolves =
        state.alivePlayers.where((p) => p.role.isWerewolf).toList();

    if (werewolves.isEmpty) return;

    // Judge announces werewolf phase
    await Future.delayed(const Duration(milliseconds: 500));

    if (werewolves.length == 1) {
      // Single werewolf decides alone
      final werewolf = werewolves.first;
      if (werewolf is AIPlayer && werewolf.isAlive) {
        try {
          // Update player event log before action
          PlayerLogger.instance.updatePlayerEvents(werewolf, state);

          await werewolf.processInformation(state);
          final target = await werewolf.chooseNightTarget(state);
          if (target != null && target.isAlive) {
            final event = werewolf.createKillEvent(target, state);
            if (event != null) {
              werewolf.executeEvent(event, state);
              LoggerUtil.instance.i('狼人选择击杀${target.formattedName}');
            } else {
              LoggerUtil.instance
                  .i('Werewolf did not choose a valid kill target');
            }
          } else {
            LoggerUtil.instance
                .i('Werewolf did not choose a valid kill target');
          }
        } catch (e) {
          LoggerUtil.instance.e('Werewolf ${werewolf.name} action failed: $e');
        }
      }
    } else {
      // Multiple werewolves - start with discussion phase
      await _processWerewolfDiscussion(werewolves);

      // Now proceed with kill decision after discussion
      final victims = <Player, int>{};

      // Collect all werewolf voting tasks
      final voteFutures = <Future<void>>[];

      for (final werewolf in werewolves) {
        if (werewolf is AIPlayer && werewolf.isAlive) {
          voteFutures.add(_processWerewolfVote(werewolf, state, victims));
        }
      }

      // Wait for all werewolves to vote simultaneously
      await Future.wait(voteFutures);

      // Select victim with most votes
      if (victims.isNotEmpty) {
        final victim =
            victims.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        final firstWerewolf = werewolves.first;
        final event = firstWerewolf.createKillEvent(victim, state);
        if (event != null) {
          firstWerewolf.executeEvent(event, state);
          LoggerUtil.instance.i('狼人选择击杀${victim.formattedName}');
        }
      } else {
        LoggerUtil.instance.i('Werewolves chose no target');
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Process single werewolf's vote (used for simultaneous voting)
  Future<void> _processWerewolfVote(
      AIPlayer werewolf, GameState state, Map<Player, int> victims) async {
    try {
      // Update player event log before action
      PlayerLogger.instance.updatePlayerEvents(werewolf, state);

      await werewolf.processInformation(state);

      // 调试：检查狼人是否能看到讨论历史
      final discussionEvents = state.eventHistory
          .whereType<WerewolfDiscussionEvent>()
          .where((e) => e.dayNumber == state.dayNumber)
          .toList();

      LoggerUtil.instance
          .d('${werewolf.name} 可见的讨论事件数量: ${discussionEvents.length}');
      if (discussionEvents.isNotEmpty) {
        LoggerUtil.instance.d('讨论内容预览: ${discussionEvents.first.message}');
      }

      final target = await werewolf.chooseNightTarget(state);
      if (target != null && target.isAlive) {
        victims[target] = (victims[target] ?? 0) + 1;
        LoggerUtil.instance
            .i('${werewolf.formattedName}选择击杀${target.formattedName}');
      } else {
        LoggerUtil.instance.i('${werewolf.name} 没有选择有效目标');
      }
    } catch (e) {
      LoggerUtil.instance.e('Werewolf ${werewolf.name} voting failed: $e');
    }
  }

  /// Process werewolf discussion phase - werewolves discuss tactics before killing
  Future<void> _processWerewolfDiscussion(List<Player> werewolves) async {
    final state = _currentState!;

    LoggerUtil.instance.i('[法官]: 狼人请睁眼');

    // Collect discussion history for this round
    final discussionHistory = <String>[];

    // Each werewolf speaks in turn to discuss strategy
    for (int i = 0; i < werewolves.length; i++) {
      final werewolf = werewolves[i];

      if (werewolf is AIPlayer && werewolf.isAlive) {
        try {
          // Update player event log before action
          PlayerLogger.instance.updatePlayerEvents(werewolf, state);

          await werewolf.processInformation(state);

          // Build context for werewolf discussion
          String context;
          if (state.dayNumber == 1) {
            // First night - use enhanced werewolf discussion prompt
            context = EnhancedPrompts.werewolfDiscussionPrompt;
          } else {
            // Later nights - based on day discussions
            context = '狼人讨论阶段：请与其他狼人队友讨论今晚的策略，包括选择击杀目标、分析场上局势等。';
          }

          if (discussionHistory.isNotEmpty) {
            context += '\n\n之前队友的发言：\n${discussionHistory.join('\n')}';
          }
          context += '\n\n现在轮到你发言，请分享你的想法和建议：';

          final statement = await werewolf.generateStatement(state, context);

          if (statement.isNotEmpty) {
            // 创建狼人讨论事件并执行
            final event =
                werewolf.createWerewolfDiscussionEvent(statement, state);
            if (event != null) {
              werewolf.executeEvent(event, state);
              LoggerUtil.instance.i(
                '${werewolf.formattedName}: $statement',
              );
              discussionHistory.add('[${werewolf.name}]: $statement');
            } else {
              LoggerUtil.instance.w(
                  '${werewolf.name} cannot create werewolf discussion event');
              LoggerUtil.instance.i('[${werewolf.formattedName}]: [无法创建讨论事件]');
            }
          } else {
            LoggerUtil.instance
                .w('${werewolf.name} generated empty statement in discussion');
            LoggerUtil.instance.i('[${werewolf.formattedName}]: [生成内容为空]');
          }
        } catch (e) {
          LoggerUtil.instance
              .e('Werewolf ${werewolf.name} discussion failed: $e');
          LoggerUtil.instance.i('[${werewolf.formattedName}]: [因技术问题无法发言]');
        }

        // Delay between werewolf discussions
        if (i < werewolves.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1200));
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 800));
  }

  /// Process guard actions - each guard acts in turn (public method)
  Future<void> processGuardActions() async {
    final state = _currentState!;
    final guards =
        state.alivePlayers.where((p) => p.role is GuardRole).toList();

    if (guards.isEmpty) return;

    await Future.delayed(const Duration(milliseconds: 500));

    LoggerUtil.instance.i('[法官]: 守卫请睁眼');
    LoggerUtil.instance.i('[法官]: 你想要守护谁？');

    // Each guard acts in turn
    for (int i = 0; i < guards.length; i++) {
      final guard = guards[i];
      if (guard is AIPlayer && guard.isAlive) {
        try {
          // Update player event log before action
          PlayerLogger.instance.updatePlayerEvents(guard, state);

          await guard.processInformation(state);
          final target = await guard.chooseNightTarget(state);
          if (target != null && target.isAlive) {
            final event = guard.createProtectEvent(target, state);
            if (event != null) {
              guard.executeEvent(event, state);
              LoggerUtil.instance
                  .i('${guard.formattedName}守护了${target.formattedName}');
            } else {
              LoggerUtil.instance
                  .i('${guard.name} made no valid protection choice');
            }
          } else {
            LoggerUtil.instance
                .i('${guard.name} made no valid protection choice');
          }
        } catch (e) {
          LoggerUtil.instance.e('Guard ${guard.name} action failed: $e');
        }

        // Delay between guard actions
        if (i < guards.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Process seer actions - each seer acts in turn (public method)
  Future<void> processSeerActions() async {
    final state = _currentState!;
    final seers = state.alivePlayers.where((p) => p.role is SeerRole).toList();

    if (seers.isEmpty) return;

    await Future.delayed(const Duration(milliseconds: 500));

    LoggerUtil.instance.i('[法官]: 预言家请睁眼');
    await Future.delayed(const Duration(milliseconds: 500));

    LoggerUtil.instance.i('[法官]: 你想要查验谁？');
    await Future.delayed(const Duration(milliseconds: 500));

    // Each seer acts in turn
    for (int i = 0; i < seers.length; i++) {
      final seer = seers[i];
      if (seer is AIPlayer && seer.isAlive) {
        try {
          // Update player event log before action
          PlayerLogger.instance.updatePlayerEvents(seer, state);

          await seer.processInformation(state);
          final target = await seer.chooseNightTarget(state);
          if (target != null && target.isAlive) {
            final event = seer.createInvestigateEvent(target, state);
            if (event != null) {
              seer.executeEvent(event, state);
              LoggerUtil.instance.i(
                  '${seer.formattedName}查验了${target.formattedName}, ${target.formattedName}是${target.role.name}');
            } else {
              LoggerUtil.instance
                  .i('${seer.name} made no valid investigation choice');
            }
          } else {
            LoggerUtil.instance
                .i('${seer.name} made no valid investigation choice');
          }
        } catch (e) {
          LoggerUtil.instance.e('${seer.name} action failed: $e');
        }

        // Delay between seer actions
        if (i < seers.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Process witch actions - each witch acts in turn (public method)
  Future<void> processWitchActions() async {
    final state = _currentState!;
    final witches =
        state.alivePlayers.where((p) => p.role is WitchRole).toList();

    if (witches.isEmpty) return;

    await Future.delayed(const Duration(milliseconds: 500));

    LoggerUtil.instance.i('[法官]: 女巫请睁眼');

    // Each witch acts in turn
    for (int i = 0; i < witches.length; i++) {
      final witch = witches[i];
      if (witch is AIPlayer && witch.role is WitchRole && witch.isAlive) {
        final witchRole = witch.role as WitchRole;

        // Tonight victim is available through state.tonightVictim
        // No need to set it in witch role anymore

        // First, ask about healing (antidote)
        if (witchRole.hasAntidote(state) && state.tonightVictim != null) {
          LoggerUtil.instance
              .i('[法官]: ${state.tonightVictim!.name}死亡. 你有一瓶解药，你要用吗？');
        } else if (witchRole.hasAntidote(state)) {
          LoggerUtil.instance.i(
              '[法官]: No one was killed tonight. Do you want to use your antidote anyway?');
        }

        // Then ask about poison
        if (witchRole.hasPoison(state)) {
          LoggerUtil.instance.i('[法官]: 你有一瓶毒药，你要用吗？');
        }

        try {
          // Update player event log before action
          PlayerLogger.instance.updatePlayerEvents(witch, state);

          await witch.processInformation(state);
          final target = await witch.chooseNightTarget(state);

          if (target != null) {
            // Witch can either heal or poison
            if (target == state.tonightVictim && witchRole.hasAntidote(state)) {
              // Try to heal the victim
              final event = witch.createHealEvent(target, state);
              if (event != null) {
                witch.executeEvent(event, state);
                LoggerUtil.instance
                    .i('[法官]: Witch chose to use antidote to ${target.name}');
              }
            } else if (target.isAlive && witchRole.hasPoison(state)) {
              // Try to poison someone
              final event = witch.createPoisonEvent(target, state);
              if (event != null) {
                witch.executeEvent(event, state);
                LoggerUtil.instance.i(
                    '[法官]: ${witch.formattedName}使用毒药攻击了${target.formattedName}');
              }
            } else {
              LoggerUtil.instance
                  .i('[法官]: Witch chose not to use potions or action invalid');
            }
          } else {
            LoggerUtil.instance.i('[法官]: Witch chose not to use potions');
          }
        } catch (e) {
          LoggerUtil.instance.e('Witch ${witch.name} action failed: $e');
          LoggerUtil.instance
              .i('[法官]: Witch chose not to use potions due to error');
        }

        // Delay between witch actions
        if (i < witches.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Resolve night action results (public method)
  Future<void> resolveNightActions() async {
    final state = _currentState!;

    final Player? victim = state.tonightVictim;
    final protected = state.tonightProtected;
    final poisoned = state.tonightPoisoned;

    // Process kill (cancelled if protected or healed)
    if (victim != null && !state.killCancelled && victim != protected) {
      victim.die(DeathCause.werewolfKill, state);
      LoggerUtil.instance.i(
        '[法官]: ${victim.formattedName} 昨晚死亡',
      );
    }

    // Process poison
    if (poisoned != null && poisoned != protected) {
      poisoned.die(DeathCause.poison, state);
      LoggerUtil.instance.i(
        '[法官]: ${poisoned.formattedName} 昨晚死亡',
      );
    }

    // Clear night action data
    state.clearNightActions();
  }

  /// Process day phase
  Future<void> _processDayPhase() async {
    final state = _currentState!;
    LoggerUtil.instance.i(
      'Phase changed to day, Day ${state.dayNumber}',
    );

    // Announce night results
    await _announceNightResults();

    // Discussion phase
    await runDiscussionPhase();

    // Move to voting phase
    await state.changePhase(GamePhase.voting);
    _stateController.add(state);
  }

  /// Announce night results
  Future<void> _announceNightResults() async {
    final state = _currentState!;

    // Filter for DeadEvent instances from tonight
    final deathEvents = state.eventHistory
        .whereType<DeadEvent>()
        .where((e) => e.dayNumber == state.dayNumber)
        .toList();

    final isPeacefulNight = deathEvents.isEmpty;

    // Create night result event with structured data
    final nightResultEvent = NightResultEvent(
      deathEvents: deathEvents,
      isPeacefulNight: isPeacefulNight,
      dayNumber: state.dayNumber,
    );
    state.addEvent(nightResultEvent);

    // Also log to console
    if (isPeacefulNight) {
      LoggerUtil.instance.i(
        '昨晚是平安夜，没有人死亡',
      );
    } else {
      for (final death in deathEvents) {
        LoggerUtil.instance.i(
          '${death.victim.name} 死亡: ${death.generateDescription()}',
        );
      }
    }
  }

  /// Run discussion phase - players speak in order (public method)
  Future<void> runDiscussionPhase() async {
    final state = _currentState!;
    final alivePlayers =
        _getActionOrder(state.alivePlayers.where((p) => p.isAlive).toList());

    // Collect speech history for this discussion round
    final discussionHistory = <String>[];

    // AI players discuss in turn, one by one
    for (int i = 0; i < alivePlayers.length; i++) {
      final player = alivePlayers[i];

      // Double check: ensure player is still alive
      if (player is AIPlayer && player.isAlive) {
        try {
          // Update player event log before action
          PlayerLogger.instance.updatePlayerEvents(player, state);

          // Ensure each step completes fully before proceeding
          await player.processInformation(state);

          // Build context including discussion history
          String context =
              'Day discussion phase, please share your views based on previous players\' statements.';
          if (discussionHistory.isNotEmpty) {
            context +=
                '\n\nPrevious players\' statements:\n${discussionHistory.join('\n')}';
          }
          context +=
              '\n\nNow it\'s your turn to speak, please share your views on the current situation and other players\' opinions:';

          // Wait for statement generation to complete fully
          final statement = await player.generateStatement(state, context);

          if (statement.isNotEmpty) {
            final event = player.createSpeakEvent(statement, state);
            if (event != null) {
              player.executeEvent(event, state);
              // Record speech to round log
              LoggerUtil.instance.i(
                '${player.formattedName}: $statement',
              );
              // Add speech to discussion history
              discussionHistory.add('[${player.name}]: $statement');
            } else {
              LoggerUtil.instance
                  .w('${player.name} cannot speak in current phase');
            }
          } else {
            LoggerUtil.instance.i('${player.formattedName} did not speak');
          }
        } catch (e) {
          LoggerUtil.instance.e('Player ${player.name} speech failed: $e');
          LoggerUtil.instance.i('${player.name} skipped speech due to error');
        }

        // Longer delay to ensure UI synchronization
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
  }

  /// Process voting phase
  Future<void> _processVotingPhase() async {
    final state = _currentState!;
    LoggerUtil.instance.i(
      'Phase changed to voting, Day ${state.dayNumber}',
    );

    // Clear previous votes
    state.clearVotes();

    // Collect votes
    await collectVotes();

    // Resolve voting
    await resolveVoting();

    // Move to next night
    state.dayNumber++;
    await state.changePhase(GamePhase.night);
    _stateController.add(state);
  }

  /// Collect votes - all players vote simultaneously (public method)
  Future<void> collectVotes({List<Player>? pkCandidates}) async {
    final state = _currentState!;
    final alivePlayers = state.alivePlayers.where((p) => p.isAlive).toList();

    // 如果是PK投票，排除PK候选人自己
    final voters = pkCandidates != null
        ? alivePlayers.where((p) => !pkCandidates.contains(p)).toList()
        : alivePlayers;

    // 收集所有玩家的投票任务
    final voteFutures = <Future<void>>[];

    for (final voter in voters) {
      if (voter is AIPlayer && voter.isAlive) {
        voteFutures.add(_processSingleVote(voter, state, pkCandidates));
      }
    }

    // 等待所有玩家同时完成投票
    await Future.wait(voteFutures);

    LoggerUtil.instance.i('[法官]: 投票结束');
  }

  /// Process single player's vote (used for simultaneous voting)
  Future<void> _processSingleVote(
      AIPlayer voter, GameState state, List<Player>? pkCandidates) async {
    try {
      // Update player event log before action
      PlayerLogger.instance.updatePlayerEvents(voter, state);

      // Each player makes their decision independently
      await voter.processInformation(state);
      final target =
          await voter.chooseVoteTarget(state, pkCandidates: pkCandidates);

      if (target != null && target.isAlive) {
        // 额外验证：如果是PK投票，确保目标在PK候选人中
        if (pkCandidates != null && !pkCandidates.contains(target)) {
          LoggerUtil.instance.w(
              '${voter.formattedName}投票给${target.formattedName} who is not in PK candidates, vote ignored');
          return;
        }

        final event = voter.createVoteEvent(target, state);
        if (event != null) {
          voter.executeEvent(event, state);
          LoggerUtil.instance
              .i('${voter.formattedName}投票给${target.formattedName}');
        } else {
          LoggerUtil.instance
              .i('${voter.formattedName} abstained or action invalid');
        }
      } else {
        LoggerUtil.instance
            .i('${voter.formattedName} abstained or action invalid');
      }
    } catch (e) {
      LoggerUtil.instance.e('Player ${voter.name} voting failed: $e');
      LoggerUtil.instance.i('${voter.name} abstained due to error');
    }
  }

  /// Resolve voting results (public method)
  Future<void> resolveVoting() async {
    final state = _currentState!;

    // 显示投票统计
    final voteResults = state.getVoteResults();
    if (voteResults.isNotEmpty) {
      final sortedResults = voteResults.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sortedResults) {
        final player = state.getPlayerById(entry.key);
        LoggerUtil.instance.i(
            '${player?.formattedName ?? '[${player?.name ?? entry.key}](${player?.role.name})'}: ${entry.value}票');
      }
    }

    final voteTarget = state.getVoteTarget();

    if (voteTarget != null) {
      // 有明确的投票结果，先处理遗言，再执行出局
      await _handleLastWords(voteTarget, 'vote');

      voteTarget.die(DeathCause.vote, state);
      LoggerUtil.instance.i('[法官]: ${voteTarget.name}被投票出局');

      // Handle hunter skill
      if (voteTarget.role is HunterRole && voteTarget.isDead) {
        await _handleHunterDeath(voteTarget);
      }
    } else {
      // 检查是否有平票
      final tiedPlayers = state.getTiedPlayers();
      if (tiedPlayers.length > 1) {
        LoggerUtil.instance.i(
          'Tied vote: ${tiedPlayers.map((p) => p.name).join(', ')} - entering PK phase',
        );
        await _handlePKPhase(tiedPlayers);
      } else if (voteResults.isEmpty) {
        LoggerUtil.instance.i('No player executed (no votes cast)');
      } else {
        LoggerUtil.instance.i('No player executed (no valid result)');
      }
    }

    state.clearVotes();
  }

  /// Handle PK (平票) phase - tied players speak, then others vote
  Future<void> _handlePKPhase(List<Player> tiedPlayers) async {
    final state = _currentState!;

    LoggerUtil.instance.i('=== PK Phase ===');
    LoggerUtil.instance.i(
      'Tied players: ${tiedPlayers.map((p) => p.name).join(', ')}',
    );

    // PK玩家依次发言
    LoggerUtil.instance.i('PK players will now speak in order...');

    for (int i = 0; i < tiedPlayers.length; i++) {
      final player = tiedPlayers[i];
      if (player is AIPlayer && player.isAlive) {
        try {
          // Update player event log before action
          PlayerLogger.instance.updatePlayerEvents(player, state);

          LoggerUtil.instance.d('Generating PK speech for ${player.name}...');

          await player.processInformation(state);
          final statement = await player.generateStatement(
            state,
            'PK发言：你在平票中，请为自己辩护，说服其他玩家不要投你出局。',
          );

          if (statement.isNotEmpty) {
            final event = player.createSpeakEvent(statement, state);
            if (event != null) {
              player.executeEvent(event, state);
              LoggerUtil.instance.i(
                '${player.formattedName} (PK): $statement',
              );
            } else {
              LoggerUtil.instance.w(
                  'Failed to create speak event for ${player.name} in PK phase');
            }
          } else {
            LoggerUtil.instance
                .w('${player.name} generated empty PK statement');
            LoggerUtil.instance.i(
              '${player.formattedName} (PK): [沉默，未发言]',
            );
          }
        } catch (e, stackTrace) {
          LoggerUtil.instance.e('PK speech failed for ${player.name}: $e');
          LoggerUtil.instance.e('Stack trace: $stackTrace');
          LoggerUtil.instance.i(
            '${player.formattedName} (PK): [因错误未能发言]',
          );
        }

        // 延迟确保每个玩家的发言被完整处理
        if (i < tiedPlayers.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
    }

    LoggerUtil.instance.i('PK speeches ended, other players will now vote...');

    // 其他玩家投票（不包括PK玩家自己）
    state.clearVotes();

    // 使用新的collectVotes方法，传入PK候选人列表
    await collectVotes(pkCandidates: tiedPlayers);

    // 统计PK投票结果
    final pkResults = state.getVoteResults();
    if (pkResults.isNotEmpty) {
      LoggerUtil.instance.i('PK voting results:');
      final sortedResults = pkResults.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sortedResults) {
        final player = state.getPlayerById(entry.key);
        LoggerUtil.instance
            .i('  ${player?.name ?? entry.key}: ${entry.value} votes');
      }
    } else {
      LoggerUtil.instance.w('No votes were cast in PK phase');
    }

    // 得出PK结果
    final pkTarget = state.getVoteTarget();
    if (pkTarget != null && tiedPlayers.contains(pkTarget)) {
      // PK阶段被淘汰的玩家先留遗言
      await _handleLastWords(pkTarget, 'pk');

      pkTarget.die(DeathCause.vote, state);
      LoggerUtil.instance.i(
        '[法官]: ${pkTarget.name} was executed by PK vote',
      );

      // Handle hunter skill
      if (pkTarget.role is HunterRole && pkTarget.isDead) {
        await _handleHunterDeath(pkTarget);
      }
    } else {
      LoggerUtil.instance.i('PK vote still tied or invalid - no one executed');
      if (pkResults.isEmpty) {
        LoggerUtil.instance.w(
            'Warning: No valid votes in PK phase, this may indicate an issue');
      }
    }
  }

  /// Handle hunter death
  Future<void> _handleHunterDeath(Player hunter) async {
    if (hunter.role is HunterRole) {
      final hunterRole = hunter.role as HunterRole;
      if (hunterRole.canShoot(_currentState!)) {
        // Simple AI: shoot most suspicious player
        if (hunter is AIPlayer) {
          final state = _currentState!;
          final suspiciousPlayers = hunter.getMostSuspiciousPlayers(state);
          if (suspiciousPlayers.isNotEmpty) {
            final target = suspiciousPlayers.first;
            final event = hunter.createHunterShootEvent(target, state);
            if (event != null) {
              hunter.executeEvent(event, state);
            }
          }
        }
      }
    }
  }

  /// Handle last words for a player about to be executed
  Future<void> _handleLastWords(Player player, String executionType) async {
    if (!player.isAlive) {
      return; // Player should still be alive when leaving last words
    }

    final state = _currentState!;
    LoggerUtil.instance.i('${player.formattedName}出局，有遗言');

    String lastWords = '';

    if (player is AIPlayer) {
      try {
        // Update player knowledge before generating last words
        PlayerLogger.instance.updatePlayerEvents(player, state);
        await player.processInformation(state);

        // Generate appropriate context based on execution type
        String context;
        switch (executionType) {
          case 'vote':
            context = '遗言：你即将被全民投票出局，请留下你的最后一段话。你可以透露身份信息、分析场上形势、或给其他玩家重要提示。';
            break;
          case 'pk':
            context = '遗言：你在PK阶段被投票出局，请留下你的最后一段话。你可以透露身份信息、分析场上形势、或给其他玩家重要提示。';
            break;
          default:
            context = '遗言：你即将离开游戏，请留下你的最后一段话。';
        }

        LoggerUtil.instance.d('Generating last words for ${player.name}...');
        lastWords = await player.generateStatement(state, context);

        if (lastWords.isEmpty) {
          lastWords = '我没有什么要说的了。'; // Default fallback
        }
      } catch (e) {
        LoggerUtil.instance
            .e('Error generating last words for ${player.name}: $e');
        lastWords = '我没有什么要说的了。'; // Fallback on error
      }
    } else {
      // For human players, we would need UI input here
      // For now, just use a placeholder
      lastWords = '再见了，各位。'; // Default for human players
    }

    // Create and execute last words event
    final event = player.createLastWordsEvent(lastWords, state);
    if (event != null) {
      player.executeEvent(event, state);
      LoggerUtil.instance.i('${player.formattedName}: $lastWords');
    } else {
      LoggerUtil.instance
          .w('Failed to create last words event for ${player.name}');
    }
  }

  /// Handle game error - don't stop game, log error and continue
  Future<void> _handleGameError(dynamic error) async {
    LoggerUtil.instance.e('Game error: $error');

    // Don't stop the game for individual player errors
    // Just log and continue
    LoggerUtil.instance.i('Game continues running, error logged');

    // Notify listeners of the error but don't change game status
    _eventController.add(SystemErrorEvent(
      errorMessage: 'Game error occurred',
      error: error,
    ));
  }

  /// End game
  Future<void> _endGame() async {
    if (_currentState == null) return;

    final state = _currentState!;
    final duration = DateTime.now().difference(state.startTime);

    _status = GameStatus.ended;
    state.endGame(state.winner ?? 'unknown');

    // 显示游戏结束信息
    LoggerUtil.instance.i('');
    LoggerUtil.instance.i('='.padRight(60, '='));
    LoggerUtil.instance.i(
      '游戏结束！',
    );
    LoggerUtil.instance.i('='.padRight(60, '='));

    // 胜利阵营
    final winnerText = state.winner == 'Good' ? '好人阵营' : '狼人阵营';
    LoggerUtil.instance.i(
      '🏆 胜利者: $winnerText',
    );

    // 游戏时长
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    LoggerUtil.instance.i('⏱️  游戏时长: $minutes分$seconds秒，共${state.dayNumber}天');

    // 存活情况
    LoggerUtil.instance.i('');
    LoggerUtil.instance.i(
      '最终存活: ${state.alivePlayers.length}人',
    );
    for (final player in state.alivePlayers) {
      final roleName = player.role.name;
      final camp = player.role.isWerewolf ? '狼人' : '好人';
      LoggerUtil.instance.i(
        '  ✓ ${player.name} - $roleName ($camp)',
      );
    }

    // 死亡情况
    if (state.deadPlayers.isNotEmpty) {
      LoggerUtil.instance.i('');
      LoggerUtil.instance.i(
        '已出局: ${state.deadPlayers.length}人',
      );
      for (final player in state.deadPlayers) {
        final roleName = player.role.name;
        final camp = player.role.isWerewolf ? '狼人' : '好人';
        LoggerUtil.instance.i(
          '  ✗ ${player.name} - $roleName ($camp)',
        );
      }
    }

    // 角色分布
    LoggerUtil.instance.i('');
    LoggerUtil.instance.i(
      '身份揭晓:',
    );

    // 狼人阵营
    final werewolves = state.players.where((p) => p.role.isWerewolf).toList();
    LoggerUtil.instance.i(
      '  🐺 狼人阵营 (${werewolves.length}人):',
    );
    for (final wolf in werewolves) {
      final status = wolf.isAlive ? '存活' : '出局';
      LoggerUtil.instance.i(
        '     ${wolf.name} - ${wolf.role.name} [$status]',
      );
    }

    // 好人阵营
    final goods = state.players.where((p) => !p.role.isWerewolf).toList();
    LoggerUtil.instance.i(
      '  👼 好人阵营 (${goods.length}人):',
    );

    // 神职
    final gods = goods.where((p) => p.role.isGod).toList();
    if (gods.isNotEmpty) {
      LoggerUtil.instance.i(
        '     神职:',
      );
      for (final god in gods) {
        final status = god.isAlive ? '存活' : '出局';
        LoggerUtil.instance.i(
          '       ${god.name} - ${god.role.name} [$status]',
        );
      }
    }

    // 平民
    final villagers = goods.where((p) => p.role.isVillager).toList();
    if (villagers.isNotEmpty) {
      LoggerUtil.instance.i(
        '     平民:',
      );
      for (final villager in villagers) {
        final status = villager.isAlive ? '存活' : '出局';
        LoggerUtil.instance.i(
          '       ${villager.name} - ${villager.role.name} [$status]',
        );
      }
    }

    LoggerUtil.instance.i('='.padRight(60, '='));
    LoggerUtil.instance.i('');

    _stateController.add(state);
    _eventController.add(state.eventHistory.last);
  }

  /// Pause game
  void pauseGame() {
    if (isGameRunning) {
      _status = GameStatus.paused;
      LoggerUtil.instance.i('Game paused');
    }
  }

  /// Resume game
  void resumeGame() {
    if (_status == GameStatus.paused) {
      _status = GameStatus.playing;
      LoggerUtil.instance.i('Game resumed');
      unawaited(_runGameLoop());
    }
  }

  /// Stop game
  void stopGame() {
    _status = GameStatus.ended;
    LoggerUtil.instance.i('Game manually stopped');

    if (_currentState != null) {
      _currentState!.endGame('manually stopped');
    }
  }

  /// Get game statistics
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

  /// Dispose game engine
  void dispose() {
    _eventController.close();
    _stateController.close();
    PlayerLogger.instance.dispose();
    LoggerUtil.instance.i('Game engine disposed');
  }
}
