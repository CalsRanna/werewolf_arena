import 'dart:async';

import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/engine/game_observer.dart';
import 'package:werewolf_arena/core/domain/entities/game_player.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_config.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_engine_status.dart';
import 'package:werewolf_arena/core/scenarios/game_scenario.dart';
import 'package:werewolf_arena/core/engine/processors/night_phase_processor.dart';
import 'package:werewolf_arena/core/engine/processors/day_phase_processor.dart';
import 'package:werewolf_arena/core/engine/utils/game_random.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/services/logging/logger.dart';

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
  
  // === 工具类 ===
  final GameRandom _random;
  
  GameEngine({
    required this.config,
    required this.scenario,
    required this.players,
    GameObserver? observer,
  }) : _observer = observer,
       _random = GameRandom(),
       _nightProcessor = NightPhaseProcessor(),
       _dayProcessor = DayPhaseProcessor();

  // === 状态查询 ===
  GameState? get currentState => _currentState;
  GameEngineStatus get status => _status;
  bool get hasGameStarted => _currentState != null;
  bool get isGameRunning => hasGameStarted && _status == GameEngineStatus.playing;
  bool get isGameEnded => hasGameStarted && _status == GameEngineStatus.ended;

  /// 初始化游戏
  Future<void> initializeGame() async {
    try {
      // 创建游戏状态
      _currentState = GameState(
        gameId: 'game_${DateTime.now().millisecondsSinceEpoch}',
        scenario: scenario,
        players: players, // 直接使用GamePlayer列表
      );
      
      // 初始化游戏
      _currentState!.startGame();
      _status = GameEngineStatus.waiting;
      
      // 通知状态更新（暂时注释掉，因为接口不匹配）
      // _observer?.onStateChange(_currentState!);
      
      LoggerUtil.instance.d('游戏初始化完成');
    } catch (e) {
      LoggerUtil.instance.e('游戏初始化失败: $e');
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
      LoggerUtil.instance.d('游戏已在运行中');
      return;
    }
    
    _status = GameEngineStatus.playing;
    
    // 通知状态更新（暂时注释掉，因为接口不匹配）
    // _observer?.onStateChange(_currentState!);
    
    LoggerUtil.instance.d('游戏开始');
  }
  
  /// 执行游戏步骤
  Future<void> executeGameStep() async {
    if (!isGameRunning || isGameEnded) return;
    
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
        return;
      }
      
      // 执行阶段处理
      await processor.process(_currentState!);
      
      // 通知状态更新（暂时注释掉，因为接口不匹配）
      // _observer?.onStateChange(_currentState!);
      
      // 检查游戏结束
      if (_currentState!.checkGameEnd()) {
        await _endGame();
      }
    } catch (e) {
      LoggerUtil.instance.e('游戏步骤执行错误: $e');
      await _handleGameError(e);
    }
  }
  
  /// 结束游戏
  Future<void> _endGame() async {
    if (_currentState == null) return;
    
    final state = _currentState!;
    
    _status = GameEngineStatus.ended;
    state.endGame(state.winner ?? 'unknown');
    
    // 通知状态更新（暂时注释掉，因为接口不匹配）
    // _observer?.onStateChange(state);
    
    LoggerUtil.instance.d('游戏结束');
  }
  
  /// 处理游戏错误
  Future<void> _handleGameError(dynamic error) async {
    LoggerUtil.instance.e('游戏错误: $error');
    
    // 不停止游戏，只记录错误并继续
    LoggerUtil.instance.d('游戏继续运行，错误已记录');
    
    // 通知观察者错误
    _observer?.onErrorMessage?.call('游戏发生错误', errorDetails: error);
  }
  
  /// 清理资源
  void dispose() {
    LoggerUtil.instance.d('游戏引擎资源清理完成');
  }
}