import 'dart:async';

import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/events/game_end_event.dart';
import 'package:werewolf_arena/engine/events/game_start_event.dart';
import 'package:werewolf_arena/engine/scenarios/game_scenario.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';

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
  // final AppConfig config; // 移除Flutter依赖
  final GameScenario scenario;

  // 核心游戏状态
  GamePhase currentPhase;
  int dayNumber;

  List<GamePlayer> players;
  final List<GameEvent> events;

  DateTime? lastUpdateTime;
  String? winner;

  // 技能效果管理（替代NightActionState和VotingState）
  final Map<String, dynamic> skillEffects; // 存储技能效果状态
  final Map<String, int> skillUsageCounts; // 跟踪技能使用次数

  // 内部日志器单例引用
  GameEngineLogger get logger => GameEngineLogger.instance;

  final _controller = StreamController<GameEvent>.broadcast();
  Stream<GameEvent> get eventStream => _controller.stream;

  GameState({
    required this.gameId,
    // required this.config, // 移除Flutter依赖
    required this.scenario,
    required this.players,
    this.currentPhase = GamePhase.night,
    this.dayNumber = 0,
    List<GameEvent>? eventHistory,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? skillEffects,
    Map<String, int>? skillUsageCounts,
  }) : events = eventHistory ?? [],
       startTime = DateTime.now(),
       skillEffects = skillEffects ?? {},
       skillUsageCounts = skillUsageCounts ?? {};

  // 基本状态查询
  bool get isNight => currentPhase == GamePhase.night;
  bool get isDay => currentPhase == GamePhase.day;
  bool get isVoting => currentPhase == GamePhase.voting;

  List<GamePlayer> get alivePlayers => players.where((p) => p.isAlive).toList();
  List<GamePlayer> get deadPlayers => players.where((p) => !p.isAlive).toList();

  List<GamePlayer> get werewolves =>
      players.where((p) => p.role.isWerewolf).toList();
  List<GamePlayer> get villagers =>
      players.where((p) => p.role.isVillager).toList();
  List<GamePlayer> get gods => players.where((p) => p.role.isGod).toList();

  int get aliveWerewolves => werewolves.where((p) => p.isAlive).length;
  int get aliveVillagers => villagers.where((p) => p.isAlive).length;
  int get aliveGoodGuys => alivePlayers.where((p) => !p.role.isWerewolf).length;

  // Methods
  Future<void> handleEvent(GameEvent event) async {
    events.add(event);
    lastUpdateTime = DateTime.now();
    _controller.add(event);
  }

  Future<void> changePhase(GamePhase newPhase) async {
    currentPhase = newPhase;
  }

  void startGame() {
    dayNumber = 1;
    currentPhase = GamePhase.night;

    final event = GameStartEvent(
      playerCount: players.length,
      roleDistribution: _getRoleDistribution(),
    );
    logger.d(event.toString());
    handleEvent(event);
  }

  void endGame(String winner) {
    this.winner = winner;

    final event = GameEndEvent(
      winner: winner,
      totalDays: dayNumber,
      finalPlayerCount: alivePlayers.length,
      gameStartTime: startTime,
    );
    logger.d(event.toString());
    handleEvent(event);
  }

  /// Check if game should end
  bool checkGameEnd() {
    logger.d('游戏结束检查: 存活狼人=$aliveWerewolves, 存活好人=$aliveGoodGuys');

    if (alivePlayers.length < 2) {
      logger.w('游戏异常：存活玩家少于2人');
      endGame('Game Error');
      return true;
    }

    final winner = _checkWinner();

    if (winner != null) {
      endGame(winner);
      return true;
    }

    logger.d('游戏继续，未达到结束条件');
    return false;
  }

  GamePlayer? getPlayerByName(String playerName) {
    try {
      return players.firstWhere((p) => p.name == playerName);
    } catch (e) {
      return null;
    }
  }

  Map<String, int> _getRoleDistribution() {
    final distribution = <String, int>{};
    for (final player in players) {
      distribution[player.role.roleId] =
          (distribution[player.role.roleId] ?? 0) + 1;
    }
    return distribution;
  }

  void dispose() {
    _controller.close();
  }

  String? _checkWinner() {
    // Good guys win: all werewolves are dead.
    if (aliveWerewolves == 0) {
      GameEngineLogger.instance.i('好人阵营获胜！所有狼人已出局');
      return '好人阵营';
    }

    // Werewolves win:
    // Condition 1: Kill all gods (if any gods exist in the game)
    final aliveGods = gods.where((p) => p.isAlive).length;
    if (gods.isNotEmpty && aliveGods == 0) {
      if (aliveWerewolves >= aliveVillagers) {
        GameEngineLogger.instance.i('狼人阵营获胜！屠神成功（所有神职已出局，狼人占优势）');
        return '狼人阵营';
      }
    }

    // Condition 2: Kill all villagers (if any villagers exist in the game)
    if (villagers.isNotEmpty && aliveVillagers == 0) {
      if (aliveWerewolves >= aliveGods) {
        GameEngineLogger.instance.i('狼人阵营获胜！屠民成功（所有平民已出局，狼人占优势）');
        return '狼人阵营';
      }
    }

    // No winner yet
    return null;
  }
}
