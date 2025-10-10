import 'dart:async';
import 'package:werewolf_arena/core/engine/game_state.dart';
import 'package:werewolf_arena/core/engine/game_event.dart';
import 'package:werewolf_arena/core/engine/game_observer.dart';
import 'package:werewolf_arena/core/player/player.dart';
import 'package:werewolf_arena/core/player/ai_player.dart';
import 'package:werewolf_arena/core/player/role.dart';
import 'package:werewolf_arena/services/llm/enhanced_prompts.dart';
import 'package:werewolf_arena/services/logging/logger.dart';
import 'package:werewolf_arena/core/engine/game_parameters.dart';
import 'package:werewolf_arena/services/config/config.dart';
import 'package:werewolf_arena/core/engine/game_scenario.dart';
import 'package:werewolf_arena/shared/random_helper.dart';
import 'package:werewolf_arena/services/logging/player_logger.dart';

/// Game engine - manages the entire game flow
class GameEngine {
  GameEngine({
    required this.parameters,
    RandomHelper? random,
    GameObserver? observer,
  }) : random = random ?? RandomHelper(),
       _observer = observer;
  final GameParameters parameters;

  /// 获取游戏配置
  AppConfig get config => parameters.config;

  /// 获取当前场景
  GameScenario get currentScenario => parameters.scenario!;
  final RandomHelper random;

  GameState? _currentState;
  GameStatus _status = GameStatus.waiting;
  final GameObserver? _observer;

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

  /// 设置游戏观察者
  void setObserver(GameObserver observer) {
    // 注意：这里不允许替换已有的观察者，因为通常我们会在构造函数中设置
    // 如果需要动态替换，可以考虑使用 CompositeGameObserver
  }

  /// 通知观察者游戏开始
  void _notifyGameStart(int playerCount, Map<String, int> roleDistribution) {
    _observer?.onGameStart(_currentState!, playerCount, roleDistribution);
  }

  /// 通知观察者游戏结束
  void _notifyGameEnd(String winner, int totalDays, int finalPlayerCount) {
    _observer?.onGameEnd(_currentState!, winner, totalDays, finalPlayerCount);
  }

  /// 通知观察者阶段转换
  void _notifyPhaseChange(
    GamePhase oldPhase,
    GamePhase newPhase,
    int dayNumber,
  ) {
    _observer?.onPhaseChange(oldPhase, newPhase, dayNumber);
  }

  /// 通知观察者玩家行动
  void _notifyPlayerAction(
    Player player,
    String actionType,
    dynamic target, {
    Map<String, dynamic>? details,
  }) {
    _observer?.onPlayerAction(player, actionType, target, details: details);
  }

  /// 通知观察者玩家死亡
  void _notifyPlayerDeath(Player player, DeathCause cause, {Player? killer}) {
    _observer?.onPlayerDeath(player, cause, killer: killer);
  }

  /// 通知观察者玩家发言
  void _notifyPlayerSpeak(
    Player player,
    String message, {
    SpeechType? speechType,
  }) {
    _observer?.onPlayerSpeak(player, message, speechType: speechType);
  }

  /// 通知观察者投票
  void _notifyVoteCast(Player voter, Player target, {VoteType? voteType}) {
    _observer?.onVoteCast(voter, target, voteType: voteType);
  }

  /// 通知观察者夜晚结果
  void _notifyNightResult(
    List<Player> deaths,
    bool isPeacefulNight,
    int dayNumber,
  ) {
    _observer?.onNightResult(deaths, isPeacefulNight, dayNumber);
  }

  /// 通知观察者系统消息
  void _notifySystemMessage(
    String message, {
    int? dayNumber,
    GamePhase? phase,
  }) {
    _observer?.onSystemMessage(message, dayNumber: dayNumber, phase: phase);
  }

  /// 通知观察者错误消息
  void _notifyErrorMessage(String error, {Object? errorDetails}) {
    _observer?.onErrorMessage(error, errorDetails: errorDetails);
  }

  /// 通知观察者投票结果
  void _notifyVoteResults(
    Map<String, int> results,
    Player? executed,
    List<Player>? pkCandidates,
  ) {
    _observer?.onVoteResults(results, executed, pkCandidates);
  }

  /// 通知观察者存活玩家公告
  void _notifyAlivePlayersAnnouncement(List<Player> alivePlayers) {
    _observer?.onAlivePlayersAnnouncement(alivePlayers);
  }

  /// 通知观察者遗言
  void _notifyLastWords(Player player, String lastWords) {
    _observer?.onLastWords(player, lastWords);
  }

  /// Initialize game
  Future<void> initializeGame() async {
    try {
      // Create initial game state (players must be set separately)
      _currentState = GameState(
        gameId: 'game_${DateTime.now().toString()}',
        config: config,
        scenario: currentScenario,
        players: [], // Will be set by setPlayers method
      );

      // Initialize player logger for debugging (after LoggerUtil gameId is set)
      PlayerLogger.instance.initialize();

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
      _notifySystemMessage('Game is already running');
      return;
    }

    _status = GameStatus.playing;
    _currentState!.startGame();

    _stateController.add(_currentState!);
    _eventController.add(_currentState!.eventHistory.last);

    // 通知回调处理器游戏开始
    if (_currentState!.eventHistory.last is GameStartEvent) {
      final startEvent = _currentState!.eventHistory.last as GameStartEvent;
      _notifyGameStart(startEvent.playerCount, startEvent.roleDistribution);
    }

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

    // 通知回调处理器阶段转换
    _notifyPhaseChange(GamePhase.day, GamePhase.night, state.dayNumber);
    _notifySystemMessage(
      '天黑请闭眼',
      dayNumber: state.dayNumber,
      phase: GamePhase.night,
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
  List<Player> _getActionOrder(
    List<Player> players, {
    bool shouldAnnounce = false,
  }) {
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

      _notifySystemMessage('法官随机选择 ${startingPlayer.name} 作为发言起始点');

      return _reorderFromStartingPoint(
        allPlayersSorted,
        players,
        randomIndex,
        shouldAnnounce: shouldAnnounce,
      );
    }

    // Find the index of the last dead player in the sorted list
    final deadPlayerIndex = allPlayersSorted.indexWhere(
      (p) => p.name == lastDeadPlayer.name,
    );
    if (deadPlayerIndex == -1) {
      // Fallback to normal ordering if something goes wrong
      return _reorderFromStartingPoint(
        allPlayersSorted,
        players,
        0,
        shouldAnnounce: shouldAnnounce,
      );
    }

    // Determine starting point (next player after the dead one)
    int startingIndex = (deadPlayerIndex + 1) % allPlayersSorted.length;

    // Find the next alive player from that position
    for (int i = 0; i < allPlayersSorted.length; i++) {
      final currentIndex = (startingIndex + i) % allPlayersSorted.length;
      final currentPlayer = allPlayersSorted[currentIndex];
      if (currentPlayer.isAlive) {
        return _reorderFromStartingPoint(
          allPlayersSorted,
          players,
          currentIndex,
          shouldAnnounce: shouldAnnounce,
        );
      }
    }

    // Should not reach here, but fallback just in case
    return _reorderFromStartingPoint(
      allPlayersSorted,
      players,
      0,
      shouldAnnounce: shouldAnnounce,
    );
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
  List<Player> _reorderFromStartingPoint(
    List<Player> allPlayersSorted,
    List<Player> alivePlayers,
    int startingIndex, {
    bool shouldAnnounce = false,
  }) {
    final orderedPlayers = <Player>[];
    final alivePlayerNames = alivePlayers.map((p) => p.name).toSet();

    // Build order string for logging
    final orderNames = <String>[];
    final isReverse = RandomHelper().nextBool();
    if (isReverse) {
      // Reverse order
      for (int i = 0; i < allPlayersSorted.length; i++) {
        final currentIndex =
            (startingIndex - i + allPlayersSorted.length) %
            allPlayersSorted.length;
        final player = allPlayersSorted[currentIndex];
        if (alivePlayerNames.contains(player.name)) {
          orderedPlayers.add(player);
          orderNames.add(player.name);
        }
      }
    } else {
      // Forward order
      for (int i = 0; i < allPlayersSorted.length; i++) {
        final currentIndex = (startingIndex + i) % allPlayersSorted.length;
        final player = allPlayersSorted[currentIndex];
        if (alivePlayerNames.contains(player.name)) {
          orderedPlayers.add(player);
          orderNames.add(player.name);
        }
      }
    }

    // Log the speaking order
    final direction = isReverse ? "逆序" : "顺序";
    _notifySystemMessage('从${orderNames.first}开始$direction发言');

    // Create speech order announcement event if requested
    if (shouldAnnounce && orderedPlayers.isNotEmpty) {
      final state = _currentState!;
      final speechOrderEvent = SpeechOrderAnnouncementEvent(
        speakingOrder: orderedPlayers,
        dayNumber: state.dayNumber,
        direction: direction,
      );
      state.addEvent(speechOrderEvent);
    }

    return orderedPlayers;
  }

  /// Process werewolf actions - if multiple werewolves, they need to negotiate (public method)
  Future<void> processWerewolfActions() async {
    final state = _currentState!;
    final werewolves = state.alivePlayers
        .where((p) => p.role.isWerewolf)
        .toList();

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
              _notifyPlayerAction(werewolf, 'kill', target);
            } else {
              // 记录到调试日志，而不是控制台
              LoggerUtil.instance.debug(
                'Werewolf did not choose a valid kill target',
              );
            }
          } else {
            // 记录到调试日志，而不是控制台
            LoggerUtil.instance.debug(
              'Werewolf did not choose a valid kill target',
            );
          }
        } catch (e) {
          LoggerUtil.instance.e('Werewolf ${werewolf.name} action failed: $e');
          final errorMsg = _formatErrorMessage(e, '狼人 ${werewolf.name} 行动失败');
          _notifyErrorMessage(errorMsg);
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
        final victim = victims.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
        final firstWerewolf = werewolves.first;
        final event = firstWerewolf.createKillEvent(victim, state);
        if (event != null) {
          firstWerewolf.executeEvent(event, state);
          _notifyPlayerAction(firstWerewolf, 'kill', victim);
        }
      } else {
        LoggerUtil.instance.debug('Werewolves chose no target');
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Process single werewolf's vote (used for simultaneous voting)
  Future<void> _processWerewolfVote(
    AIPlayer werewolf,
    GameState state,
    Map<Player, int> victims,
  ) async {
    try {
      // Update player event log before action
      PlayerLogger.instance.updatePlayerEvents(werewolf, state);

      await werewolf.processInformation(state);

      // 调试：检查狼人是否能看到讨论历史
      final discussionEvents = state.eventHistory
          .whereType<WerewolfDiscussionEvent>()
          .where((e) => e.dayNumber == state.dayNumber)
          .toList();

      LoggerUtil.instance.d(
        '${werewolf.name} 可见的讨论事件数量: ${discussionEvents.length}',
      );
      if (discussionEvents.isNotEmpty) {
        LoggerUtil.instance.d('讨论内容预览: ${discussionEvents.first.message}');
      }

      final target = await werewolf.chooseNightTarget(state);
      if (target != null && target.isAlive) {
        victims[target] = (victims[target] ?? 0) + 1;
        // 这个信息已经通过 _notifyVoteCast 通知了
      } else {
        LoggerUtil.instance.debug('${werewolf.name} 没有选择有效目标');
      }
    } catch (e) {
      LoggerUtil.instance.e('Werewolf ${werewolf.name} voting failed: $e');
      final errorMsg = _formatErrorMessage(e, '狼人 ${werewolf.name} 投票失败');
      _notifyErrorMessage(errorMsg);
    }
  }

  /// Process werewolf discussion phase - werewolves discuss tactics before killing
  Future<void> _processWerewolfDiscussion(List<Player> werewolves) async {
    final state = _currentState!;

    _notifySystemMessage('狼人请睁眼');

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
            final event = werewolf.createWerewolfDiscussionEvent(
              statement,
              state,
            );
            if (event != null) {
              werewolf.executeEvent(event, state);
              _notifyPlayerSpeak(
                werewolf,
                statement,
                speechType: SpeechType.werewolfDiscussion,
              );
              discussionHistory.add('[${werewolf.name}]: $statement');
            } else {
              LoggerUtil.instance.debug(
                '${werewolf.name} cannot create werewolf discussion event',
              );
            }
          } else {
            LoggerUtil.instance.debug('${werewolf.formattedName}没有发言');
          }
        } catch (e) {
          LoggerUtil.instance.e(
            'Werewolf ${werewolf.name} discussion failed: $e',
          );
          _notifyErrorMessage('${werewolf.formattedName}: 因技术问题无法发言');
        }

        // Delay between werewolf discussions
        if (i < werewolves.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1200));
        }
      }
    }

    _notifySystemMessage('狼人请选择击杀目标');
    await Future.delayed(const Duration(milliseconds: 800));
  }

  /// Process guard actions - each guard acts in turn (public method)
  Future<void> processGuardActions() async {
    final state = _currentState!;
    final guards = state.alivePlayers
        .where((p) => p.role is GuardRole)
        .toList();

    if (guards.isEmpty) return;

    await Future.delayed(const Duration(milliseconds: 500));

    _notifySystemMessage('守卫请睁眼');
    _notifySystemMessage('你想要守护谁？');

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
              _notifyPlayerAction(guard, 'protect', target);
            } else {
              LoggerUtil.instance.debug(
                '${guard.name} made no valid protection choice',
              );
            }
          } else {
            LoggerUtil.instance.debug(
              '${guard.name} made no valid protection choice',
            );
          }
        } catch (e) {
          LoggerUtil.instance.e('Guard ${guard.name} action failed: $e');
          _notifyErrorMessage('守卫 ${guard.name} 行动失败: $e');
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

    _notifySystemMessage('预言家请睁眼');
    await Future.delayed(const Duration(milliseconds: 500));

    _notifySystemMessage('你想要查验谁？');
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
              _notifyPlayerAction(
                seer,
                'investigate',
                target,
                details: {'result': target.role.name},
              );
            } else {
              LoggerUtil.instance.debug(
                '${seer.name} made no valid investigation choice',
              );
            }
          } else {
            LoggerUtil.instance.debug(
              '${seer.name} made no valid investigation choice',
            );
          }
        } catch (e) {
          LoggerUtil.instance.e('${seer.name} action failed: $e');
          _notifyErrorMessage('预言家 ${seer.name} 行动失败: $e');
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
    final witches = state.alivePlayers
        .where((p) => p.role is WitchRole)
        .toList();

    if (witches.isEmpty) return;

    await Future.delayed(const Duration(milliseconds: 500));

    _notifySystemMessage('女巫请睁眼');

    // Each witch acts in turn
    for (int i = 0; i < witches.length; i++) {
      final witch = witches[i];
      if (witch is AIPlayer && witch.role is WitchRole && witch.isAlive) {
        final witchRole = witch.role as WitchRole;

        // Tonight victim is available through state.tonightVictim
        // No need to set it in witch role anymore

        // Step 1: Handle antidote decision
        if (witchRole.hasAntidote(state)) {
          if (state.tonightVictim != null) {
            _notifySystemMessage(
              '${state.tonightVictim!.name}死亡. 你有一瓶解药，你要用吗？',
            );
          } else {
            _notifySystemMessage('平安夜. 你有一瓶解药，你要使用吗？');
          }

          // Give witch time to think about antidote
          await Future.delayed(Duration(milliseconds: 1000));

          try {
            // Update player event log before action
            PlayerLogger.instance.updatePlayerEvents(witch, state);
            await witch.processInformation(state);

            // Ask witch specifically about antidote
            final shouldUseAntidote = await _askWitchAboutAntidote(
              witch,
              state,
            );

            if (shouldUseAntidote && state.tonightVictim != null) {
              final event = witch.createHealEvent(state.tonightVictim!, state);
              if (event != null) {
                witch.executeEvent(event, state);
                _notifyPlayerAction(witch, 'heal', state.tonightVictim!);
              }
            } else {
              _notifySystemMessage('${witch.formattedName}选择不使用解药');
            }
          } catch (e) {
            LoggerUtil.instance.e(
              'Witch ${witch.name} antidote decision failed: $e',
            );
            _notifyErrorMessage('女巫 ${witch.name} 解药决策失败: $e');
            _notifySystemMessage('${witch.formattedName}选择不使用解药');
          }
        }

        // Step 2: Handle poison decision (separate from antidote)
        if (witchRole.hasPoison(state)) {
          _notifySystemMessage('你有一瓶毒药，你要使用吗？');

          // Give witch time to think about poison
          await Future.delayed(Duration(milliseconds: 1000));

          try {
            // Ask witch specifically about poison
            final poisonTarget = await _askWitchAboutPoison(witch, state);

            if (poisonTarget != null) {
              final event = witch.createPoisonEvent(poisonTarget, state);
              if (event != null) {
                witch.executeEvent(event, state);
                _notifyPlayerAction(witch, 'poison', poisonTarget);

                // 添加公告事件，通知所有玩家有人被毒（但不说明是谁毒的）
                final announcement = JudgeAnnouncementEvent(
                  announcement: '${poisonTarget.formattedName}昨晚被毒杀',
                  dayNumber: state.dayNumber,
                  phase: state.currentPhase,
                );
                state.addEvent(announcement);
              }
            } else {
              _notifySystemMessage('${witch.formattedName}选择不使用毒药');
            }
          } catch (e) {
            LoggerUtil.instance.e(
              'Witch ${witch.name} poison decision failed: $e',
            );
            _notifyErrorMessage('女巫 ${witch.name} 毒药决策失败: $e');
            _notifySystemMessage('${witch.formattedName}选择不使用毒药');
          }
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
      _notifyPlayerDeath(victim, DeathCause.werewolfKill);
    }

    // Process poison
    if (poisoned != null && poisoned != protected) {
      poisoned.die(DeathCause.poison, state);
      _notifyPlayerDeath(poisoned, DeathCause.poison);
    }

    // Clear night action data
    state.clearNightActions();
  }

  /// Process day phase
  Future<void> _processDayPhase() async {
    final state = _currentState!;
    _notifyPhaseChange(GamePhase.night, GamePhase.day, state.dayNumber);
    _notifySystemMessage(
      '天亮了',
      dayNumber: state.dayNumber,
      phase: GamePhase.day,
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

    // 通知回调处理器夜晚结果
    _notifyNightResult(
      deathEvents.map((e) => e.victim).toList(),
      isPeacefulNight,
      state.dayNumber,
    );

    // Announce current alive players
    final alivePlayers = state.alivePlayers;
    _notifyAlivePlayersAnnouncement(alivePlayers);
  }

  /// Run discussion phase - players speak in order (public method)
  Future<void> runDiscussionPhase() async {
    final state = _currentState!;
    final alivePlayers = _getActionOrder(
      state.alivePlayers.where((p) => p.isAlive).toList(),
      shouldAnnounce: true,
    );

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
              // 通知回调处理器玩家发言
              _notifyPlayerSpeak(player, statement);
              // Add speech to discussion history
              discussionHistory.add('[${player.name}]: $statement');
            } else {
              LoggerUtil.instance.debug(
                '${player.name} cannot speak in current phase',
              );
            }
          } else {
            LoggerUtil.instance.debug('${player.formattedName} did not speak');
          }
        } catch (e) {
          LoggerUtil.instance.e('Player ${player.name} speech failed: $e');
          _notifyErrorMessage('${player.name} skipped speech due to error');
        }

        // Longer delay to ensure UI synchronization
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
  }

  /// Process voting phase
  Future<void> _processVotingPhase() async {
    final state = _currentState!;
    _notifyPhaseChange(GamePhase.day, GamePhase.voting, state.dayNumber);
    _notifySystemMessage(
      '现在开始投票',
      dayNumber: state.dayNumber,
      phase: GamePhase.voting,
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

    _notifySystemMessage('投票结束');
  }

  /// Process single player's vote (used for simultaneous voting)
  Future<void> _processSingleVote(
    AIPlayer voter,
    GameState state,
    List<Player>? pkCandidates,
  ) async {
    try {
      // Update player event log before action
      PlayerLogger.instance.updatePlayerEvents(voter, state);

      // Each player makes their decision independently
      await voter.processInformation(state);
      final target = await voter.chooseVoteTarget(
        state,
        pkCandidates: pkCandidates,
      );

      if (target != null && target.isAlive) {
        // 额外验证：如果是PK投票，确保目标在PK候选人中
        if (pkCandidates != null && !pkCandidates.contains(target)) {
          LoggerUtil.instance.w(
            '${voter.formattedName}投票给${target.formattedName} who is not in PK candidates, vote ignored',
          );
          return;
        }

        final event = voter.createVoteEvent(target, state);
        if (event != null) {
          voter.executeEvent(event, state);
          _notifyVoteCast(
            voter,
            target,
            voteType: pkCandidates != null ? VoteType.pk : VoteType.normal,
          );
        } else {
          LoggerUtil.instance.debug(
            '${voter.formattedName} abstained or action invalid',
          );
        }
      } else {
        LoggerUtil.instance.debug(
          '${voter.formattedName} abstained or action invalid',
        );
      }
    } catch (e) {
      LoggerUtil.instance.e('Player ${voter.name} voting failed: $e');
      _notifyErrorMessage('玩家 ${voter.name} 投票失败: $e');
    }
  }

  /// Resolve voting results (public method)
  Future<void> resolveVoting() async {
    final state = _currentState!;

    // 显示投票统计
    final voteResults = state.getVoteResults();
    final voteTarget = state.getVoteTarget();
    final tiedPlayers = state.getTiedPlayers();

    // 通知回调处理器投票结果
    _notifyVoteResults(
      voteResults,
      voteTarget,
      tiedPlayers.isNotEmpty ? tiedPlayers : null,
    );

    if (voteTarget != null) {
      // 有明确的投票结果，先处理遗言，再执行出局
      await _handleLastWords(voteTarget, 'vote');

      voteTarget.die(DeathCause.vote, state);
      _notifyPlayerDeath(voteTarget, DeathCause.vote);

      // Handle hunter skill
      if (voteTarget.role is HunterRole && voteTarget.isDead) {
        await _handleHunterDeath(voteTarget);
      }
    } else {
      // 检查是否有平票
      final tiedPlayers = state.getTiedPlayers();
      if (tiedPlayers.length > 1) {
        _notifySystemMessage(
          '${tiedPlayers.map((p) => p.formattedName).join(', ')}平票',
        );
        await _handlePKPhase(tiedPlayers);
      } else if (voteResults.isEmpty) {
        LoggerUtil.instance.debug('No player executed (no votes cast)');
      } else {
        LoggerUtil.instance.debug('No player executed (no valid result)');
      }
    }

    state.clearVotes();
  }

  /// Handle PK (平票) phase - tied players speak, then others vote
  Future<void> _handlePKPhase(List<Player> tiedPlayers) async {
    final state = _currentState!;

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
              _notifyPlayerSpeak(player, statement);
            } else {
              LoggerUtil.instance.debug(
                'Failed to create speak event for ${player.name} in PK phase',
              );
            }
          } else {
            LoggerUtil.instance.debug(
              '${player.name} generated empty PK statement',
            );
          }
        } catch (e, stackTrace) {
          LoggerUtil.instance.e('PK speech failed for ${player.name}: $e');
          LoggerUtil.instance.e('Stack trace: $stackTrace');
          _notifyErrorMessage('${player.formattedName} (PK): [因错误未能发言]');
        }

        // 延迟确保每个玩家的发言被完整处理
        if (i < tiedPlayers.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
    }

    _notifySystemMessage('PK发言结束，其他玩家现在开始投票');

    // 其他玩家投票（不包括PK玩家自己）
    state.clearVotes();

    // 使用新的collectVotes方法，传入PK候选人列表
    await collectVotes(pkCandidates: tiedPlayers);

    // 统计PK投票结果
    final pkResults = state.getVoteResults();
    if (pkResults.isNotEmpty) {
      _notifySystemMessage('PK投票结果：');
      final sortedResults = pkResults.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sortedResults) {
        final player = state.getPlayerByName(entry.key);
        LoggerUtil.instance.i(
          '  ${player?.name ?? entry.key}: ${entry.value} votes',
        );
      }
    } else {
      _notifySystemMessage('PK阶段没有投票');
    }

    // 得出PK结果
    final pkTarget = state.getVoteTarget();
    if (pkTarget != null && tiedPlayers.contains(pkTarget)) {
      // PK阶段被淘汰的玩家先留遗言
      await _handleLastWords(pkTarget, 'pk');

      pkTarget.die(DeathCause.vote, state);
      LoggerUtil.instance.i('[法官]: ${pkTarget.name} was executed by PK vote');

      // Handle hunter skill
      if (pkTarget.role is HunterRole && pkTarget.isDead) {
        await _handleHunterDeath(pkTarget);
      }
    } else {
      _notifySystemMessage('PK投票仍然平票或无效，没有人出局');
      if (pkResults.isEmpty) {
        LoggerUtil.instance.w(
          'Warning: No valid votes in PK phase, this may indicate an issue',
        );
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
    _notifySystemMessage('${player.formattedName}出局，有遗言');

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
        LoggerUtil.instance.e(
          'Error generating last words for ${player.name}: $e',
        );
        _notifyErrorMessage('玩家 ${player.name} 遗言生成失败: $e');
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
      _notifyLastWords(player, lastWords);
    } else {
      LoggerUtil.instance.debug(
        'Failed to create last words event for ${player.name}',
      );
    }
  }

  /// Handle game error - don't stop game, log error and continue
  Future<void> _handleGameError(dynamic error) async {
    LoggerUtil.instance.e('Game error: $error');

    // Don't stop the game for individual player errors
    // Just log and continue
    LoggerUtil.instance.debug('Game continues running, error logged');

    // Notify listeners of the error but don't change game status
    _eventController.add(
      SystemErrorEvent(errorMessage: 'Game error occurred', error: error),
    );

    // 通知回调处理器错误
    _notifyErrorMessage('Game error occurred', errorDetails: error);
  }

  /// End game
  Future<void> _endGame() async {
    if (_currentState == null) return;

    final state = _currentState!;

    _status = GameStatus.ended;
    state.endGame(state.winner ?? 'unknown');

    // 通知回调处理器游戏结束
    _notifyGameEnd(
      state.winner ?? 'unknown',
      state.dayNumber,
      state.alivePlayers.length,
    );

    _stateController.add(state);
    _eventController.add(state.eventHistory.last);
  }

  /// Ask witch specifically about antidote usage
  Future<bool> _askWitchAboutAntidote(AIPlayer witch, GameState state) async {
    try {
      // Create a specific prompt for antidote decision
      final antidotePrompt =
          '''
你是一个女巫。今晚${state.tonightVictim?.formattedName ?? '没有玩家'}死亡。

你现在需要决定是否使用你的解药：
- 如果使用解药，可以救活今晚死亡的玩家
- 解药只能使用一次，使用后就没有了
- 如果不使用，解药可以保留到后续夜晚

请简单回答：
- "使用解药" - 救活今晚死亡的玩家
- "不使用解药" - 保留解药到后续夜晚

${state.tonightVictim == null ? '今晚是平安夜，没有人死亡。' : ''}
''';

      // Get LLM decision for antidote
      final response = await (witch as EnhancedAIPlayer).llmService
          .generateSimpleDecision(
            player: witch,
            prompt: antidotePrompt,
            options: ['使用解药', '不使用解药'],
            state: state,
          );

      return response == '使用解药';
    } catch (e) {
      LoggerUtil.instance.e('Error asking witch about antidote: $e');
      _notifyErrorMessage('女巫解药查询失败: $e');
      return false; // Default to not using antidote on error
    }
  }

  /// Ask witch specifically about poison usage and target
  Future<Player?> _askWitchAboutPoison(AIPlayer witch, GameState state) async {
    try {
      // Create a specific prompt for poison decision
      final poisonPrompt =
          '''
你是一个女巫。你有一瓶毒药可以毒杀一名玩家。

现在你需要决定是否使用毒药：
- 如果使用毒药，选择一名玩家进行毒杀
- 毒药只能使用一次，使用后就没有了
- 你可以毒杀任何存活的玩家（包括你自己，但不推荐）
- 考虑当前的游戏局势和谁是可疑的狼人

请回答：
1. 是否使用毒药（"使用毒药" 或 "不使用毒药"）
2. 如果选择使用，指定要毒杀的玩家编号

当前存活的玩家：
${state.players.where((p) => p.isAlive).map((p) => '- ${p.name}').join('\n')}
''';

      // Get LLM decision for poison
      final response = await (witch as EnhancedAIPlayer).llmService
          .generatePoisonDecision(
            player: witch,
            prompt: poisonPrompt,
            state: state,
          );

      return response;
    } catch (e) {
      LoggerUtil.instance.e('Error asking witch about poison: $e');
      _notifyErrorMessage('女巫毒药查询失败: $e');
      return null; // Default to not using poison on error
    }
  }

  /// Dispose game engine
  void dispose() {
    _eventController.close();
    _stateController.close();
    PlayerLogger.instance.dispose();
  }

  /// 格式化错误消息，提供更友好的提示
  String _formatErrorMessage(dynamic error, String context) {
    final errorStr = error.toString();

    // 检查是否是API密钥相关的错误
    if (errorStr.contains('YOUR_KEY_HERE') ||
        errorStr.contains('API key') ||
        errorStr.contains('Unauthorized') ||
        errorStr.contains('401')) {
      return '$context - API密钥未配置或无效。请在config/llm_config.yaml中配置正确的API密钥';
    }

    // 检查是否是网络相关的错误
    if (errorStr.contains('SocketException') ||
        errorStr.contains('Connection') ||
        errorStr.contains('timeout')) {
      return '$context - 网络连接失败。请检查网络连接和API服务是否可用';
    }

    // 检查是否是OpenAI API错误
    if (errorStr.contains('OpenAI')) {
      return '$context - LLM服务调用失败: $errorStr';
    }

    // 默认错误消息
    return '$context: $errorStr';
  }
}
