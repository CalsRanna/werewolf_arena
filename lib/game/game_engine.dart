import 'dart:async';
import 'game_state.dart';
import '../player/player.dart';
import '../player/role.dart';
import '../utils/logger_util.dart';
import '../utils/config_loader.dart';
import '../utils/random_helper.dart';

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
        gameId: 'game_${DateTime.now().millisecondsSinceEpoch}',
        config: config,
        players: [], // Will be set by setPlayers method
      );

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
    LoggerUtil.instance.i('Players set, count: ${players.length}');

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
      addToLLMContext: true,
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

  /// Get player action order
  List<Player> _getActionOrder(List<Player> players) {
    if (config.actionOrder.isSequential) {
      // Sort by numbers in player names (e.g., "Player 1", "Player 2")
      final sortedPlayers = List<Player>.from(players);
      sortedPlayers.sort((a, b) {
        // Extract numbers from player names
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
      // Random order (maintain original logic)
      return players;
    }
  }

  /// Process werewolf actions - if multiple werewolves, they need to negotiate (public method)
  Future<void> processWerewolfActions() async {
    final state = _currentState!;
    final werewolves =
        state.alivePlayers.where((p) => p.role.isWerewolf).toList();

    if (werewolves.isEmpty) return;

    // Judge announces werewolf phase
    await Future.delayed(const Duration(milliseconds: 500));

    LoggerUtil.instance.i('Processing werewolf actions...');

    if (werewolves.length == 1) {
      // Single werewolf decides alone
      final werewolf = werewolves.first;
      if (werewolf is AIPlayer && werewolf.isAlive) {
        try {
          await werewolf.processInformation(state);
          final target = await werewolf.chooseNightTarget(state);
          if (target != null && target.isAlive) {
            final event = werewolf.createKillEvent(target, state);
            if (event != null) {
              werewolf.executeEvent(event, state);
              LoggerUtil.instance.i('Werewolf chose victim: ${target.name}');
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
      final victims = <Player, int>{};

      for (int i = 0; i < werewolves.length; i++) {
        final werewolf = werewolves[i];
        if (werewolf is AIPlayer && werewolf.isAlive) {
          try {
            await werewolf.processInformation(state);
            final target = await werewolf.chooseNightTarget(state);
            if (target != null && target.isAlive) {
              victims[target] = (victims[target] ?? 0) + 1;
              LoggerUtil.instance
                  .i('${werewolf.name} chose to kill ${target.name}');
            } else {
              LoggerUtil.instance.i('${werewolf.name} made no valid choice');
            }
          } catch (e) {
            LoggerUtil.instance
                .e('Werewolf ${werewolf.name} action failed: $e');
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
        final firstWerewolf = werewolves.first;
        final event = firstWerewolf.createKillEvent(victim, state);
        if (event != null) {
          firstWerewolf.executeEvent(event, state);
          LoggerUtil.instance
              .i('Werewolves finally chose victim: ${victim.name}');
        }
      } else {
        LoggerUtil.instance.i('Werewolves chose no target');
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Process guard actions - each guard acts in turn (public method)
  Future<void> processGuardActions() async {
    final state = _currentState!;
    final guards =
        state.alivePlayers.where((p) => p.role is GuardRole).toList();

    if (guards.isEmpty) return;

    await Future.delayed(const Duration(milliseconds: 500));

    LoggerUtil.instance.i('Processing guard actions...');

    // Each guard acts in turn
    for (int i = 0; i < guards.length; i++) {
      final guard = guards[i];
      if (guard is AIPlayer && guard.isAlive) {
        LoggerUtil.instance.i('${guard.name} is choosing protect target...');
        try {
          await guard.processInformation(state);
          final target = await guard.chooseNightTarget(state);
          if (target != null && target.isAlive) {
            final event = guard.createProtectEvent(target, state);
            if (event != null) {
              guard.executeEvent(event, state);
              LoggerUtil.instance.i('${guard.name} protected ${target.name}');
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

    LoggerUtil.instance.i('[Judge] Seer please open your eyes');
    await Future.delayed(const Duration(milliseconds: 500));

    LoggerUtil.instance.i('[Judge] Who do you want to investigate?');
    await Future.delayed(const Duration(milliseconds: 500));

    // Each seer acts in turn
    for (int i = 0; i < seers.length; i++) {
      final seer = seers[i];
      if (seer is AIPlayer && seer.isAlive) {
        try {
          await seer.processInformation(state);
          final target = await seer.chooseNightTarget(state);
          if (target != null && target.isAlive) {
            final event = seer.createInvestigateEvent(target, state);
            if (event != null) {
              seer.executeEvent(event, state);
              LoggerUtil.instance.i(
                  '[${seer.name}][${seer.role.name}] investigated ${target.name}, ${target.name} is ${target.role.name}');
            } else {
              LoggerUtil.instance.i(
                  '[${seer.name}][${seer.role.name}] made no valid investigation choice');
            }
          } else {
            LoggerUtil.instance.i(
                '[${seer.name}][${seer.role.name}] made no valid investigation choice');
          }
        } catch (e) {
          LoggerUtil.instance
              .e('[${seer.name}][${seer.role.name}] action failed: $e');
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

    LoggerUtil.instance.i('Processing witch actions...');

    // Each witch acts in turn
    for (int i = 0; i < witches.length; i++) {
      final witch = witches[i];
      if (witch is AIPlayer && witch.role is WitchRole && witch.isAlive) {
        final witchRole = witch.role as WitchRole;

        // Set tonight victim for witch decision
        witchRole.setTonightVictim(state.tonightVictim);

        LoggerUtil.instance
            .i('${witch.name} is considering whether to use potions...');

        try {
          await witch.processInformation(state);
          final target = await witch.chooseNightTarget(state);

          if (target != null) {
            // Witch can either heal or poison
            if (target == state.tonightVictim && witchRole.hasAntidote) {
              // Try to heal the victim
              final event = witch.createHealEvent(target, state);
              if (event != null) {
                witch.executeEvent(event, state);
                LoggerUtil.instance.i('${witch.name} used heal potion');
              }
            } else if (target.isAlive && witchRole.hasPoison) {
              // Try to poison someone
              final event = witch.createPoisonEvent(target, state);
              if (event != null) {
                witch.executeEvent(event, state);
                LoggerUtil.instance
                    .i('${witch.name} used poison to kill ${target.name}');
              }
            } else {
              LoggerUtil.instance.i(
                  '${witch.name} chose not to use potions or action invalid');
            }
          } else {
            LoggerUtil.instance.i('${witch.name} chose not to use potions');
          }
        } catch (e) {
          LoggerUtil.instance.e('Witch ${witch.name} action failed: $e');
          LoggerUtil.instance
              .i('${witch.name} chose not to use potions due to error');
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

    LoggerUtil.instance.i('Resolving night actions...');

    final Player? victim = state.tonightVictim;
    final protected = state.tonightProtected;
    final poisoned = state.tonightPoisoned;

    // Process kill (cancelled if protected or healed)
    if (victim != null && !state.killCancelled && victim != protected) {
      victim.die('killed by werewolf', state);
      LoggerUtil.instance.i(
        '[Judge]: ${victim.name} died yesterday night',
        addToLLMContext: true,
      );
    }

    // Process poison
    if (poisoned != null && poisoned != protected) {
      poisoned.die('poisoned to death', state);
      LoggerUtil.instance.i(
        '[Judge]: ${poisoned.name} died yesterday night',
        addToLLMContext: true,
      );
    }

    // Clear night action data
    state.clearNightActions();

    // Reduce skill cooldowns
    for (final player in state.alivePlayers) {
      player.reduceSkillCooldowns();
    }
  }

  /// Process day phase
  Future<void> _processDayPhase() async {
    final state = _currentState!;
    LoggerUtil.instance.i(
      'Phase changed to day, Day ${state.dayNumber}',
      addToLLMContext: true,
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
    final deathsTonight = state.eventHistory
        .where((e) => e.type == GameEventType.playerDeath)
        .toList();

    // Collect death information
    final deathMessages = <String>[];
    if (deathsTonight.isEmpty) {
      deathMessages.add('Peaceful night, no deaths');
    } else {
      for (final death in deathsTonight) {
        final victim = death.target;
        if (victim != null) {
          deathMessages.add('${victim.name} died: ${death.description}');
        } else {
          deathMessages.add(death.description);
        }
      }
    }

    if (deathsTonight.isEmpty) {
      LoggerUtil.instance.i('Peaceful night, no deaths');
    } else {
      for (final death in deathsTonight) {
        LoggerUtil.instance
            .i('${death.target?.name} died: ${death.description}');
      }
    }
  }

  /// Run discussion phase - players speak in order (public method)
  Future<void> runDiscussionPhase() async {
    final state = _currentState!;
    final alivePlayers =
        _getActionOrder(state.alivePlayers.where((p) => p.isAlive).toList());

    LoggerUtil.instance.i('Starting discussion phase...');

    // Collect speech history for this discussion round
    final discussionHistory = <String>[];

    // AI players discuss in turn, one by one
    for (int i = 0; i < alivePlayers.length; i++) {
      final player = alivePlayers[i];

      // Double check: ensure player is still alive
      if (player is AIPlayer && player.isAlive) {
        try {
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
              LoggerUtil.instance
                  .i('[${player.name}]: $statement', addToLLMContext: true);
              // Add speech to discussion history
              discussionHistory.add('[${player.name}]: $statement');
            } else {
              LoggerUtil.instance
                  .w('${player.name} cannot speak in current phase');
            }
          } else {
            LoggerUtil.instance.i('${player.name} did not speak');
          }
        } catch (e) {
          LoggerUtil.instance.e('Player ${player.name} speech failed: $e');
          LoggerUtil.instance.i('${player.name} skipped speech due to error');
        }

        // Longer delay to ensure UI synchronization
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }

    LoggerUtil.instance.i('Discussion phase ended');
    // Wait for user confirmation to continue
    await waitForUserConfirmation(
        'Discussion ended, press Enter to proceed to voting phase...');
  }

  /// Process voting phase
  Future<void> _processVotingPhase() async {
    final state = _currentState!;
    LoggerUtil.instance.i(
      'Phase changed to voting, Day ${state.dayNumber}',
      addToLLMContext: true,
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

  /// Collect votes - players vote in order (public method)
  Future<void> collectVotes() async {
    final state = _currentState!;
    final alivePlayers =
        _getActionOrder(state.alivePlayers.where((p) => p.isAlive).toList());

    LoggerUtil.instance.i('Collecting votes...');

    // Each player votes in turn
    for (int i = 0; i < alivePlayers.length; i++) {
      final voter = alivePlayers[i];

      // Double check: ensure player is still alive and can vote
      if (voter is AIPlayer && voter.isAlive) {
        LoggerUtil.instance.i('${voter.name} is voting...');
        try {
          // Ensure each step completes fully
          await voter.processInformation(state);
          final target = await voter.chooseVoteTarget(state);

          if (target != null && target.isAlive) {
            final event = voter.createVoteEvent(target, state);
            if (event != null) {
              voter.executeEvent(event, state);
              LoggerUtil.instance.i('${voter.name} voted for ${target.name}');
            } else {
              LoggerUtil.instance
                  .i('${voter.name} abstained or action invalid');
            }
          } else {
            LoggerUtil.instance.i('${voter.name} abstained or action invalid');
          }

          // Mark completion before moving to next player
        } catch (e) {
          LoggerUtil.instance.e('Player ${voter.name} voting failed: $e');
          LoggerUtil.instance.i('${voter.name} abstained due to error');
        }

        // Longer delay to ensure proper sequencing
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }

    LoggerUtil.instance
        .i('Votes collected: ${state.totalVotes}/${state.alivePlayers.length}');
  }

  /// Resolve voting results (public method)
  Future<void> resolveVoting() async {
    final state = _currentState!;
    final voteTarget = state.getVoteTarget();

    if (voteTarget != null) {
      // Execute player
      voteTarget.die('executed by vote', state);
      LoggerUtil.instance.i(
        '[Judge]: ${voteTarget.name} was executed by vote',
        addToLLMContext: true,
      );

      // Handle hunter skill
      if (voteTarget.role is HunterRole && voteTarget.isDead) {
        await _handleHunterDeath(voteTarget);
      }
    } else {
      LoggerUtil.instance.i('No player executed (majority vote not reached)');
    }

    state.clearVotes();
  }

  /// Handle hunter death
  Future<void> _handleHunterDeath(Player hunter) async {
    if (hunter.role is HunterRole) {
      final hunterRole = hunter.role as HunterRole;
      if (hunterRole.canShoot(_currentState!)) {
        LoggerUtil.instance.i('Hunter can shoot!');

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

  /// Wait for user confirmation
  Future<void> waitForUserConfirmation(String message) async {
    // In console app, we'll use stdin for user input
    print(message);
    // TODO: Implement proper console input handling
  }

  /// Handle game error - don't stop game, log error and continue
  Future<void> _handleGameError(dynamic error) async {
    LoggerUtil.instance.e('Game error: $error');

    // Don't stop the game for individual player errors
    // Just log and continue
    LoggerUtil.instance.i('Game continues running, error logged');

    // Notify listeners of the error but don't change game status
    _eventController.add(GameEvent(
      eventId: 'error_${DateTime.now().millisecondsSinceEpoch}',
      type: GameEventType.playerAction,
      description: 'Game error occurred: $error',
      data: {'error': error.toString()},
    ));
  }

  /// End game
  Future<void> _endGame() async {
    if (_currentState == null) return;

    final state = _currentState!;
    final duration = DateTime.now().difference(state.startTime);

    _status = GameStatus.ended;
    state.endGame(state.winner ?? 'unknown');

    // Judge announces game end
    final playerRoles = <String, String>{};
    for (final player in state.players) {
      playerRoles[player.name] = player.role.name;
    }

    LoggerUtil.instance.i(
      'Game ended: ${state.gameId}, winner: ${state.winner ?? 'unknown'}, duration: ${duration.inMilliseconds}ms',
    );
    LoggerUtil.instance.i(
        'Game completed in ${state.dayNumber} days with ${state.players.length} players');

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
    LoggerUtil.instance.i('Game engine disposed');
  }
}
