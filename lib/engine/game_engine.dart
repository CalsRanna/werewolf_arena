import 'dart:async';

import 'package:werewolf_arena/engine/game_config.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/game_engine_status.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/player/ai_player.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/game_round/game_round_controller.dart';
import 'package:werewolf_arena/engine/scenario/game_scenario.dart';

/// 简化版游戏引擎 - 只需要4个参数的构造函数，内部创建阶段处理器和工具类
class GameEngine {
  final GameConfig config;
  final GameScenario scenario;
  final List<GamePlayer> players;
  final GameObserver? _observer;
  final GameRoundController controller;

  GameState? _currentState;
  GameEngineStatus _status = GameEngineStatus.waiting;

  GameEngine({
    required this.config,
    required this.scenario,
    required this.players,
    GameObserver? observer,
    required this.controller,
  }) : _observer = observer;

  // === 状态查询 ===
  GameState? get currentState => _currentState;
  bool get hasGameStarted => _currentState != null;
  bool get isGameEnded => hasGameStarted && _status == GameEngineStatus.ended;
  bool get isGameRunning =>
      hasGameStarted && _status == GameEngineStatus.playing;
  GameEngineStatus get status => _status;

  /// 清理资源
  void dispose() {
    _currentState?.dispose();
    GameEngineLogger.instance.d('游戏引擎资源清理完成');
  }

  /// 初始化游戏
  Future<void> ensureInitialized() async {
    try {
      // 设置日志器的观察者
      GameEngineLogger.instance.setObserver(_observer);

      // 创建游戏状态
      _currentState = GameState(
        gameId: 'game_${DateTime.now().millisecondsSinceEpoch}',
        scenario: scenario,
        players: players, // 直接使用GamePlayer列表
      );

      // 初始化游戏
      _currentState!.startGame();

      // 初始化所有玩家的记忆
      await _initializeAIPlayerMemories();

      _status = GameEngineStatus.playing; // 设置为进行中状态
    } catch (e) {
      GameEngineLogger.instance.e('游戏初始化失败: $e');
      await _handleGameError(e);
      rethrow;
    }
  }

  /// 初始化AI玩家记忆
  ///
  /// 在游戏开始时为所有AI玩家初始化记忆
  Future<void> _initializeAIPlayerMemories() async {
    if (_currentState == null) return;

    final state = _currentState!;
    final aiPlayers = state.players.whereType<AIPlayer>().toList();
    final futures = aiPlayers.map((player) async {
      try {
        final initialMemory = await player.driver.updateMemory(
          player: player,
          currentMemory: '',
          currentRoundEvents: [],
          state: state,
        );
        player.memory = initialMemory;
      } catch (e) {
        GameEngineLogger.instance.e('初始化${player.name}的记忆失败: $e');
      }
    }).toList();
    await Future.wait(futures);
  }

  /// 执行游戏步骤
  /// 返回bool表示是否还有下一步骤可执行
  Future<bool> loop() async {
    if (!isGameRunning || isGameEnded) return false;

    try {
      // 执行阶段处理
      await controller.tick(_currentState!, observer: _observer);

      // 检查游戏结束
      if (_currentState!.checkGameEnd()) {
        await endGame();
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
  Future<void> endGame() async {
    if (_currentState == null) return;

    final state = _currentState!;

    _status = GameEngineStatus.ended;
    state.endGame(state.winner ?? 'unknown');

    GameEngineLogger.instance.i('游戏结束');

    // 延迟一小段时间，确保 GameEndEvent 被 observer 处理
    await Future.delayed(Duration(milliseconds: 100));

    // 关闭事件流，防止后续事件发送
    state.dispose();
  }

  /// 处理游戏错误
  Future<void> _handleGameError(dynamic error) async {
    GameEngineLogger.instance.e('游戏错误: $error');

    // 不停止游戏，只记录错误并继续
    GameEngineLogger.instance.d('游戏继续运行，错误已记录');
  }
}
