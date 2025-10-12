import 'dart:async';

import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/events/phase_events.dart';
import 'package:werewolf_arena/engine/events/player_events.dart';
import 'package:werewolf_arena/engine/events/system_events.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_config.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_engine_status.dart';
import 'package:werewolf_arena/engine/scenarios/game_scenario.dart';
import 'package:werewolf_arena/engine/processors/night_phase_processor.dart';
import 'package:werewolf_arena/engine/processors/day_phase_processor.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';

/// 简化版游戏引擎 - 只需要4个参数的构造函数，内部创建阶段处理器和工具类
class GameEngine {
  // === 外部输入 ===
  final GameConfig config;
  final GameScenario scenario;
  final List<GamePlayer> players;
  final GameObserver? _observer;

  // === 核心状态 ===
  GameState? _currentState;
  GameEngineStatus _status = GameEngineStatus.waiting;

  // === 阶段处理器 ===
  final NightPhaseProcessor _nightProcessor;
  final DayPhaseProcessor _dayProcessor;

  GameEngine({
    required this.config,
    required this.scenario,
    required this.players,
    GameObserver? observer,
  }) : _observer = observer,
       _nightProcessor = NightPhaseProcessor(),
       _dayProcessor = DayPhaseProcessor();

  // === 状态查询 ===
  GameState? get currentState => _currentState;
  GameEngineStatus get status => _status;
  bool get hasGameStarted => _currentState != null;
  bool get isGameRunning =>
      hasGameStarted && _status == GameEngineStatus.playing;
  bool get isGameEnded => hasGameStarted && _status == GameEngineStatus.ended;

  void _listenEvent(GameEvent event) {
    switch (event) {
      case GameStartEvent():
        _observer?.onGameStart(
          _currentState!,
          players.length,
          _getRoleDistribution(),
        );
      case GameEndEvent():
        _observer?.onGameEnd(
          _currentState!,
          event.winner,
          event.totalDays,
          event.finalPlayerCount,
        );
      case DeadEvent():
        _observer?.onGamePlayerDeath(event.victim, event.cause);
      case PhaseChangeEvent():
        _observer?.onPhaseChange(
          event.oldPhase,
          event.newPhase,
          event.dayNumber,
        );
      case JudgeAnnouncementEvent():
        _observer?.onSystemMessage(event.announcement);
      default:
        break;
    }
  }

  /// 初始化游戏
  Future<void> initializeGame() async {
    try {
      // 设置日志器的观察者
      GameEngineLogger.instance.setObserver(_observer);

      // 创建游戏状态
      _currentState = GameState(
        gameId: 'game_${DateTime.now().millisecondsSinceEpoch}',
        scenario: scenario,
        players: players, // 直接使用GamePlayer列表
      );
      _currentState!.eventStream.listen(_listenEvent);

      // 初始化游戏
      _currentState!.startGame();
      _status = GameEngineStatus.playing; // 设置为进行中状态

      GameEngineLogger.instance.i('游戏初始化完成');
    } catch (e) {
      GameEngineLogger.instance.e('游戏初始化失败: $e');
      await _handleGameError(e);
      rethrow;
    }
  }

  /// 开始游戏
  Future<void> startGame() async {
    if (!hasGameStarted) {
      await initializeGame();
    }

    if (isGameRunning) {
      GameEngineLogger.instance.d('游戏已在运行中');
      return;
    }

    _status = GameEngineStatus.playing;

    GameEngineLogger.instance.i('游戏开始');
  }

  /// 执行游戏步骤
  /// 返回bool表示是否还有下一步骤可执行
  Future<bool> executeGameStep() async {
    if (!isGameRunning || isGameEnded) return false;

    try {
      // 根据当前阶段选择对应的处理器
      final processor = switch (_currentState!.currentPhase) {
        GamePhase.night => _nightProcessor,
        GamePhase.day => _dayProcessor,
        GamePhase.voting => _dayProcessor, // 投票合并到白天阶段
        GamePhase.ended => null, // 游戏结束时不需要处理器
      };

      // 如果游戏已结束，直接返回
      if (processor == null) {
        return false;
      }

      // 执行阶段处理
      await processor.process(_currentState!);

      // 检查游戏结束
      if (_currentState!.checkGameEnd()) {
        await _endGame();
        return false; // 游戏结束，没有下一步
      }

      return true; // 还有下一步可执行
    } catch (e) {
      GameEngineLogger.instance.e('游戏步骤执行错误: $e');
      await _handleGameError(e);
      return false; // 出错时停止执行
    }
  }

  /// 结束游戏
  Future<void> _endGame() async {
    if (_currentState == null) return;

    final state = _currentState!;

    _status = GameEngineStatus.ended;
    state.endGame(state.winner ?? 'unknown');

    GameEngineLogger.instance.i('游戏结束');
  }

  /// 获取角色分布统计
  Map<String, int> _getRoleDistribution() {
    final distribution = <String, int>{};
    for (final player in players) {
      final roleName = player.role.name;
      distribution[roleName] = (distribution[roleName] ?? 0) + 1;
    }
    return distribution;
  }

  /// 处理游戏错误
  Future<void> _handleGameError(dynamic error) async {
    GameEngineLogger.instance.e('游戏错误: $error');

    // 不停止游戏，只记录错误并继续
    GameEngineLogger.instance.d('游戏继续运行，错误已记录');
  }

  /// 清理资源
  void dispose() {
    _currentState?.dispose();
    GameEngineLogger.instance.d('游戏引擎资源清理完成');
  }
}
