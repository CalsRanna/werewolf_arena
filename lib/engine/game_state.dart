import 'dart:async';

import 'package:werewolf_arena/engine/event/game_end_event.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/event/game_start_event.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/scenario/game_scenario.dart';

/// 简化后的游戏状态类 - 专注于纯游戏逻辑状态
///
/// 职责：
/// - 管理玩家列表和基本游戏信息
/// - 管理事件历史
/// - 管理当前游戏阶段和天数
/// - 提供游戏状态查询接口
/// - 技能效果管理
class GameState {
  final String gameId;
  final DateTime startTime;
  final GameScenario scenario;

  int day;

  List<GamePlayer> players;
  final List<GameEvent> events;

  DateTime? lastUpdateTime;
  String? winner;

  bool canUserHeal = true;
  bool canUserPoison = true;
  String lastProtectedPlayer = '';

  final _controller = StreamController<GameEvent>.broadcast();
  bool _isDisposed = false;

  GameState({
    required this.gameId,
    // required this.config, // 移除Flutter依赖
    required this.scenario,
    required this.players,
    this.day = 0,
    List<GameEvent>? eventHistory,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? skillEffects,
    Map<String, int>? skillUsageCounts,
  }) : events = eventHistory ?? [],
       startTime = DateTime.now();

  Stream<GameEvent> get eventStream => _controller.stream;

  // 内部日志器单例引用
  GameEngineLogger get logger => GameEngineLogger.instance;

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
      endGame('Game Error');
      return true;
    }

    final winner = scenario.getWinner(this);
    if (winner != null) {
      endGame(winner);
      return true;
    }
    return false;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _controller.close();
  }

  void endGame(String winner) {
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
}
