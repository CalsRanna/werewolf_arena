import 'dart:async';
import 'package:werewolf_arena/core/engine/game_engine_new.dart';
import 'package:werewolf_arena/core/engine/game_assembler.dart';
import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/domain/entities/game_player.dart';
import 'package:werewolf_arena/services/stream_game_observer.dart';

/// 游戏服务 - Flutter 友好的包装层
///
/// 基于新架构的游戏服务：
/// - 使用GameAssembler创建游戏引擎
/// - 保持Stream事件流的兼容性
/// - 简化接口，专注于UI层需要的功能
/// 
/// 主要变化：
/// - 不再需要GameParameters，使用GameAssembler的4参数模式
/// - GameEngine通过GameAssembler外部创建
/// - 保持原有的Stream接口以确保UI层兼容性
class GameService {
  bool _isInitialized = false;
  GameEngine? _gameEngine;
  StreamGameObserver? _observer;
  bool _isExecutingStep = false;

  // 公开的事件流（委托给内部观察者）
  Stream<String> get gameEvents =>
      _observer?.gameEvents ?? const Stream.empty();
  Stream<void> get gameStartStream =>
      _observer?.gameStartStream ?? const Stream.empty();
  Stream<String> get phaseChangeStream =>
      _observer?.phaseChangeStream ?? const Stream.empty();
  Stream<String> get playerActionStream =>
      _observer?.playerActionStream ?? const Stream.empty();
  Stream<String> get gameEndStream =>
      _observer?.gameEndStream ?? const Stream.empty();
  Stream<String> get errorStream =>
      _observer?.errorStream ?? const Stream.empty();
  Stream<GameState> get gameStateChangedStream =>
      _observer?.gameStateChangedStream ?? const Stream.empty();

  /// 获取当前游戏状态
  GameState? get currentState => _gameEngine?.currentState;

  /// 游戏是否已开始
  bool get hasGameStarted => _gameEngine?.hasGameStarted ?? false;

  /// 游戏是否正在运行
  bool get isGameRunning => _gameEngine?.isGameRunning ?? false;

  /// 游戏是否已结束
  bool get isGameEnded => _gameEngine?.isGameEnded ?? true;

  /// 是否正在执行步骤
  bool get isExecutingStep => _isExecutingStep;

  /// 初始化游戏服务
  /// 
  /// 新架构下只需要创建观察者，游戏引擎通过createGame方法创建
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 创建观察者
    _observer = StreamGameObserver();

    _isInitialized = true;
  }

  /// 创建新游戏
  /// 
  /// 使用GameAssembler创建游戏引擎，支持配置参数：
  /// - [configPath]: 配置文件路径（可选）
  /// - [scenarioId]: 场景ID（可选，如'9_players'）
  /// - [playerCount]: 玩家数量（可选）
  /// 
  /// 这是新架构的主要接口，替代了旧的setPlayers方法
  Future<void> createGame({
    String? configPath,
    String? scenarioId,
    int? playerCount,
  }) async {
    _ensureInitialized();

    // 清理旧游戏
    await _cleanupCurrentGame();

    try {
      // 使用GameAssembler创建游戏引擎
      _gameEngine = await GameAssembler.assembleGame(
        configPath: configPath,
        scenarioId: scenarioId,
        playerCount: playerCount,
        observer: _observer,
      );

      // 初始化游戏
      await _gameEngine!.initializeGame();
    } catch (e) {
      // 如果创建失败，清理状态
      _gameEngine = null;
      rethrow;
    }
  }

  /// 快速创建游戏的便捷方法
  /// 
  /// 使用常见的配置快速创建游戏
  Future<void> createQuickGame({int playerCount = 9}) async {
    await createGame(
      scenarioId: '${playerCount}_players',
      playerCount: playerCount,
    );
  }

  /// 获取当前玩家列表
  List<GamePlayer> getCurrentPlayers() {
    _ensureInitialized();
    return _gameEngine?.players ?? [];
  }

  /// 执行下一步
  Future<void> executeNextStep() async {
    _ensureInitialized();

    if (_isExecutingStep || _gameEngine == null) {
      return;
    }

    try {
      _isExecutingStep = true;
      await _gameEngine!.executeGameStep();
    } finally {
      _isExecutingStep = false;
    }
  }

  /// 重置游戏
  /// 
  /// 清理当前游戏状态，准备创建新游戏
  Future<void> resetGame() async {
    _ensureInitialized();

    // 重置执行标志
    _isExecutingStep = false;

    // 清理当前游戏
    await _cleanupCurrentGame();
  }

  /// 清理当前游戏
  /// 
  /// 内部方法，用于清理游戏引擎状态
  Future<void> _cleanupCurrentGame() async {
    // 等待当前步骤完成
    while (_isExecutingStep) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 清理游戏引擎
    _gameEngine = null;
    
    // 注意：不清理观察者，因为UI层可能还在监听
  }

  /// 确保已初始化
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('GameService未初始化，请先调用initialize()');
    }
  }

  /// 释放资源
  /// 
  /// 清理所有资源，包括游戏引擎和观察者
  void dispose() {
    _gameEngine = null;
    _observer?.dispose();
    _observer = null;
    _isInitialized = false;
  }

  // 兼容性方法 - 为了保持与现有UI层的兼容性
  
  /// @deprecated 使用createGame替代
  /// 
  /// 保留此方法以确保现有代码的兼容性
  @Deprecated('使用createGame方法替代')
  Future<void> initializeGame() async {
    // 如果没有游戏引擎，创建一个默认游戏
    if (_gameEngine == null) {
      await createQuickGame();
    }
  }

  /// @deprecated 使用createGame替代
  /// 
  /// 保留此方法以确保现有代码的兼容性
  @Deprecated('使用createGame方法替代')
  void setPlayers(List<dynamic> players) {
    // 这个方法在新架构中不再需要，因为玩家由GameAssembler创建
    // 为了兼容性，这里只是一个空实现
  }

  /// @deprecated 使用createGame替代
  /// 
  /// 保留此方法以确保现有代码的兼容性
  @Deprecated('使用createGame方法替代')
  void setGamePlayers(List<dynamic> players) {
    // 这个方法在新架构中不再需要，因为玩家由GameAssembler创建
    // 为了兼容性，这里只是一个空实现
  }

  /// @deprecated 使用getCurrentPlayers替代
  /// 
  /// 保留此方法以确保现有代码的兼容性
  @Deprecated('使用getCurrentPlayers方法替代')
  List<dynamic> getCurrentGamePlayers() {
    _ensureInitialized();
    return _gameEngine?.players ?? [];
  }

  /// @deprecated 使用executeNextStep替代
  /// 
  /// 保留此方法以确保现有代码的兼容性
  @Deprecated('使用executeNextStep方法替代')
  Future<void> startGame() async {
    await executeNextStep();
  }
}
