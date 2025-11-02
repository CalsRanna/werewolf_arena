import 'dart:async';

import 'package:werewolf_arena/engine/event/game_end_event.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/event/game_start_event.dart';
import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/game_logger.dart';
import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/round/game_round_controller.dart';
import 'package:werewolf_arena/engine/scenario/game_scenario.dart';

/// 游戏实例类 - 管理单个游戏会话
///
/// 职责：
/// - 管理玩家列表和基本游戏信息
/// - 管理事件历史
/// - 管理当前游戏阶段和天数
/// - 提供游戏状态查询接口
/// - 技能效果管理
/// - 执行游戏循环（loop）
/// - 处理游戏结束逻辑
class Game {
  final String gameId;
  final DateTime startTime;
  final GameScenario scenario;
  final GameRoundController controller;
  final GameObserver? _observer;

  int day;

  List<GamePlayer> players;
  final List<GameEvent> events;

  DateTime? lastUpdateTime;
  String? winner;

  bool canUserHeal = true;
  bool canUserPoison = true;
  String lastProtectedPlayer = '';

  /// 当前警长
  GamePlayer? sheriff;

  /// 警徽流历史(记录警徽传递链)
  final List<String> badgeHistory = [];

  final _controller = StreamController<GameEvent>.broadcast();
  bool _isDisposed = false;
  bool _isEnded = false;

  Game({
    required this.gameId,
    required this.scenario,
    required this.players,
    required this.controller,
    GameObserver? observer,
    this.day = 0,
    List<GameEvent>? eventHistory,
  }) : events = eventHistory ?? [],
       startTime = DateTime.now(),
       _observer = observer;

  Stream<GameEvent> get eventStream => _controller.stream;

  // 内部日志器单例引用
  GameLogger get logger => GameLogger.instance;

  // === 状态查询 ===
  bool get hasGameStarted => day > 0;
  bool get isGameEnded => _isEnded;
  bool get isGameRunning => hasGameStarted && !_isEnded;

  List<GamePlayer> get alivePlayers => players.where((p) => p.isAlive).toList();
  List<GamePlayer> get deadPlayers => players.where((p) => !p.isAlive).toList();

  List<GamePlayer> get gods {
    return players
        .where((p) => p.role.id != 'werewolf' && p.role.id != 'villager')
        .toList();
  }

  List<GamePlayer> get villagers {
    return players.where((p) => p.role.id == 'villager').toList();
  }

  List<GamePlayer> get werewolves {
    return players.where((p) => p.role.id == 'werewolf').toList();
  }

  int get aliveVillagers => villagers.where((p) => p.isAlive).length;
  int get aliveWerewolves => werewolves.where((p) => p.isAlive).length;
  int get aliveGods => gods.where((p) => p.isAlive).length;

  /// Check if game should end
  bool checkGameEnd() {
    if (alivePlayers.length < 2) {
      logger.w('游戏异常：存活玩家少于2人');
      _endGameInternal('Game Error');
      return true;
    }

    // 构建用于检查胜利条件的上下文（包含所有公开信息）
    final context = GameContext(
      day: day,
      scenario: scenario,
      allPlayers: List.unmodifiable(players),
      alivePlayers: List.unmodifiable(alivePlayers),
      visibleEvents: List.unmodifiable(events),
      canWitchHeal: canUserHeal,
      canWitchPoison: canUserPoison,
      lastProtectedPlayer: lastProtectedPlayer,
      sheriff: sheriff,
      badgeHistory: List.unmodifiable(badgeHistory),
    );

    final winner = scenario.getWinner(context);
    if (winner != null) {
      _endGameInternal(winner);
      return true;
    }
    return false;
  }

  /// 清理资源
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _controller.close();
    logger.d('游戏资源清理完成');
  }

  /// 初始化并启动游戏
  Future<void> ensureInitialized() async {
    try {
      // 设置日志器的观察者
      GameLogger.instance.setObserver(_observer);

      // 启动游戏
      startGame();
    } catch (e) {
      logger.e('游戏初始化失败: $e');
      rethrow;
    }
  }

  /// 执行游戏步骤
  /// 返回bool表示是否还有下一步骤可执行
  Future<bool> loop() async {
    if (!isGameRunning || isGameEnded) return false;

    try {
      // 执行阶段处理
      await controller.tick(this, observer: _observer);

      // 检查游戏结束
      if (checkGameEnd()) {
        await endGame();
        return false; // 游戏结束，没有下一步
      }

      return true; // 还有下一步可执行
    } catch (e) {
      logger.e('游戏步骤执行错误: $e');
      await _handleGameError(e);
      return false; // 出错时停止执行
    }
  }

  /// 结束游戏（外部调用接口）
  Future<void> endGame() async {
    _isEnded = true;
    _endGameInternal(winner ?? 'unknown');

    logger.i('游戏结束');

    // 延迟一小段时间，确保 GameEndEvent 被 observer 处理
    await Future.delayed(Duration(milliseconds: 100));

    // 关闭事件流，防止后续事件发送
    dispose();
  }

  /// 内部游戏结束逻辑
  void _endGameInternal(String winner) {
    this.winner = winner;

    final event = GameEndEvent(
      winner: winner,
      totalDays: day,
      finalPlayerCount: alivePlayers.length,
      gameStartTime: startTime,
      day: day,
    );
    logger.d(event.toString());
    handleEvent(event);
  }

  GamePlayer? getPlayerByName(String playerName) {
    try {
      return players.firstWhere((p) => p.name == playerName);
    } catch (e) {
      return null;
    }
  }

  // Methods
  Future<void> handleEvent(GameEvent event) async {
    // 如果游戏已结束且当前事件不是 GameEndEvent，则不处理新事件
    if (winner != null && event is! GameEndEvent) {
      logger.d('游戏已结束，忽略事件: ${event.runtimeType}');
      return;
    }

    // 如果事件流已关闭，不再添加事件
    if (_isDisposed) {
      logger.d('事件流已关闭，忽略事件: ${event.runtimeType}');
      return;
    }

    events.add(event);
    lastUpdateTime = DateTime.now();
    _controller.add(event);
  }

  void startGame() {
    day = 1;

    final event = GameStartEvent();
    logger.d(event.toString());
    handleEvent(event);
  }

  /// 为指定玩家构建游戏上下文
  ///
  /// 根据玩家的角色权限过滤可见信息
  GameContext buildContextForPlayer(GamePlayer player) {
    // 过滤该玩家可见的事件
    final visibleEvents = events.where((event) {
      return event.isVisibleTo(player);
    }).toList();

    return GameContext(
      day: day,
      scenario: scenario,
      allPlayers: List.unmodifiable(players),
      alivePlayers: List.unmodifiable(alivePlayers),
      visibleEvents: List.unmodifiable(visibleEvents),
      canWitchHeal: canUserHeal,
      canWitchPoison: canUserPoison,
      lastProtectedPlayer: lastProtectedPlayer,
      sheriff: sheriff,
      badgeHistory: List.unmodifiable(badgeHistory),
    );
  }


  /// 处理游戏错误
  Future<void> _handleGameError(dynamic error) async {
    logger.e('游戏错误: $error');

    // 不停止游戏，只记录错误并继续
    logger.d('游戏继续运行，错误已记录');
  }
}
