import 'dart:async';
import 'package:werewolf_arena/core/engine/game_engine.dart';
import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/entities/player/player.dart';
import 'package:werewolf_arena/core/interfaces/game_parameters.dart';
import 'package:werewolf_arena/services/config/config.dart';
import 'package:werewolf_arena/services/stream_game_observer.dart';
import 'package:werewolf_arena/shared/random_helper.dart';

/// 游戏服务 - Flutter 友好的包装层
///
/// 提供游戏引擎的高级接口，适用于 Flutter UI 层。
/// 内部使用 StreamGameObserver 将游戏事件转换为 Stream，
/// 同时提供游戏控制方法（初始化、开始、执行步骤等）。
class GameService {
  bool _isInitialized = false;
  GameEngine? _gameEngine;
  GameParameters? _gameParameters;
  StreamGameObserver? _observer;
  bool _isExecutingStep = false;

  // 公开的事件流（委托给内部观察者）
  Stream<String> get gameEvents => _observer?.gameEvents ?? const Stream.empty();
  Stream<void> get gameStartStream => _observer?.gameStartStream ?? const Stream.empty();
  Stream<String> get phaseChangeStream => _observer?.phaseChangeStream ?? const Stream.empty();
  Stream<String> get playerActionStream => _observer?.playerActionStream ?? const Stream.empty();
  Stream<String> get gameEndStream => _observer?.gameEndStream ?? const Stream.empty();
  Stream<String> get errorStream => _observer?.errorStream ?? const Stream.empty();
  Stream<GameState> get gameStateChangedStream =>
      _observer?.gameStateChangedStream ?? const Stream.empty();

  /// 获取当前游戏状态
  GameState? get currentState => _gameEngine?.currentState;

  /// 游戏是否已结束
  bool get isGameEnded => _gameEngine?.isGameEnded ?? true;

  /// 是否正在执行步骤
  bool get isExecutingStep => _isExecutingStep;

  /// 初始化游戏服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    _gameParameters = FlutterGameParameters.instance;

    // 创建观察者
    _observer = StreamGameObserver();

    // 创建游戏引擎并设置观察者
    _gameEngine = GameEngine(
      parameters: _gameParameters!,
      random: RandomHelper(),
      observer: _observer,
    );

    _isInitialized = true;
  }

  /// 初始化游戏
  Future<void> initializeGame() async {
    _ensureInitialized();
    await _gameEngine!.initializeGame();
  }

  /// 设置玩家列表
  void setPlayers(List<Player> players) {
    _ensureInitialized();
    _gameEngine!.setPlayers(players);
  }

  /// 获取当前玩家列表
  List<Player> getCurrentPlayers() {
    _ensureInitialized();
    return _gameEngine!.currentState?.players ?? [];
  }

  /// 开始游戏
  Future<void> startGame() async {
    _ensureInitialized();
    await _gameEngine!.startGame();
  }

  /// 执行下一步
  Future<void> executeNextStep() async {
    _ensureInitialized();

    if (_isExecutingStep) {
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
  Future<void> resetGame() async {
    _ensureInitialized();

    // 重置执行标志
    _isExecutingStep = false;

    // 清理旧引擎
    _gameEngine?.dispose();

    // 清理旧观察者
    _observer?.dispose();

    // 创建新观察者
    _observer = StreamGameObserver();

    // 创建新引擎
    _gameEngine = GameEngine(
      parameters: _gameParameters!,
      random: RandomHelper(),
      observer: _observer,
    );
  }

  /// 确保已初始化
  void _ensureInitialized() {
    if (!_isInitialized || _gameEngine == null) {
      throw StateError('GameService未初始化,请先调用initialize()');
    }
  }

  /// 释放资源
  void dispose() {
    _gameEngine?.dispose();
    _observer?.dispose();
  }
}
