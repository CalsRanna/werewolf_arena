import 'dart:async';
import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/events/base/game_event.dart';
import 'package:werewolf_arena/core/events/system_events.dart';
import 'package:werewolf_arena/core/engine/game_observer.dart';
import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/services/logging/logger.dart';
import 'package:werewolf_arena/core/engine/game_parameters.dart';
import 'package:werewolf_arena/services/config/config.dart';
import 'package:werewolf_arena/core/scenarios/game_scenario.dart';
import 'package:werewolf_arena/shared/random_helper.dart';
import 'package:werewolf_arena/services/logging/player_logger.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_status.dart';
import 'package:werewolf_arena/core/engine/processors/phase_processor.dart';
import 'package:werewolf_arena/core/engine/processors/night_phase_processor.dart';
import 'package:werewolf_arena/core/engine/processors/day_phase_processor.dart';
import 'package:werewolf_arena/core/engine/processors/voting_phase_processor.dart';
import 'package:werewolf_arena/core/engine/processors/werewolf_action_processor.dart';
import 'package:werewolf_arena/core/engine/processors/guard_action_processor.dart';
import 'package:werewolf_arena/core/engine/processors/seer_action_processor.dart';
import 'package:werewolf_arena/core/engine/processors/witch_action_processor.dart';

/// Game engine - manages the entire game flow using processor pattern
class GameEngine {
  GameEngine({
    required this.parameters,
    RandomHelper? random,
    GameObserver? observer,
  }) : random = random ?? RandomHelper(),
       _observer = observer,
       _phaseProcessors = _initializePhaseProcessors();
  final GameParameters parameters;

  /// 获取游戏配置
  AppConfig get config => parameters.config;

  /// 获取当前场景
  GameScenario get currentScenario => parameters.scenario!;
  final RandomHelper random;

  // 处理器
  final Map<GamePhase, PhaseProcessor> _phaseProcessors;

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

  /// 初始化阶段处理器
  static Map<GamePhase, PhaseProcessor> _initializePhaseProcessors() {
    return {
      GamePhase.night: NightPhaseProcessor(),
      GamePhase.day: DayPhaseProcessor(),
      GamePhase.voting: VotingPhaseProcessor(),
    };
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

  /// Process game phase using processor pattern
  Future<void> _processGamePhase() async {
    final state = _currentState!;

    // 通知阶段转换
    final oldPhase = state.currentPhase;
    _notifyPhaseChange(oldPhase, state.currentPhase, state.dayNumber);

    // 获取对应的阶段处理器
    final processor = _phaseProcessors[state.currentPhase];
    if (processor == null) {
      LoggerUtil.instance.e('未找到阶段 ${state.currentPhase} 的处理器');
      return;
    }

    try {
      // 使用处理器处理当前阶段
      await processor.process(state);

      // 通知状态更新
      _stateController.add(state);

      LoggerUtil.instance.d('阶段 ${state.currentPhase} 处理完成');
    } catch (e) {
      LoggerUtil.instance.e('阶段 ${state.currentPhase} 处理失败: $e');
      await _handleGameError(e);
    }
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

  /// Dispose game engine
  void dispose() {
    _eventController.close();
    _stateController.close();
    PlayerLogger.instance.dispose();
  }
}
