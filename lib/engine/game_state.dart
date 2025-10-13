import 'dart:async';

import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/events/dead_event.dart';
import 'package:werewolf_arena/engine/events/game_end_event.dart';
import 'package:werewolf_arena/engine/events/game_start_event.dart';
import 'package:werewolf_arena/engine/events/phase_change_event.dart';
// import 'package:werewolf_arena/services/config/config.dart'; // 移除Flutter依赖
import 'package:werewolf_arena/engine/scenarios/game_scenario.dart';
import 'package:werewolf_arena/engine/scenarios/scenario_9_players.dart'; // 重新导入新的场景类
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/rules/victory_conditions.dart';

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
  final List<GameEvent> eventHistory;
  final Map<String, dynamic> metadata;

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
  }) : eventHistory = eventHistory ?? [],
       startTime = DateTime.now(),
       metadata = metadata ?? {},
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

  // 技能效果管理方法
  /// 设置技能效果
  void setSkillEffect(String effectKey, dynamic value) {
    skillEffects[effectKey] = value;
    lastUpdateTime = DateTime.now();
  }

  /// 获取技能效果
  T? getSkillEffect<T>(String effectKey) {
    return skillEffects[effectKey] as T?;
  }

  /// 移除技能效果
  void removeSkillEffect(String effectKey) {
    skillEffects.remove(effectKey);
    lastUpdateTime = DateTime.now();
  }

  /// 检查技能效果是否存在
  bool hasSkillEffect(String effectKey) {
    return skillEffects.containsKey(effectKey);
  }

  /// 增加技能使用次数
  void incrementSkillUsage(String skillId) {
    skillUsageCounts[skillId] = (skillUsageCounts[skillId] ?? 0) + 1;
    lastUpdateTime = DateTime.now();
  }

  /// 获取技能使用次数
  int getSkillUsageCount(String skillId) {
    return skillUsageCounts[skillId] ?? 0;
  }

  /// 重置技能使用次数
  void resetSkillUsage(String skillId) {
    skillUsageCounts.remove(skillId);
    lastUpdateTime = DateTime.now();
  }

  /// 清空所有技能效果（通常在阶段转换时使用）
  void clearSkillEffects() {
    skillEffects.clear();
    lastUpdateTime = DateTime.now();
  }

  // Methods
  void addEvent(GameEvent event) {
    eventHistory.add(event);
    lastUpdateTime = DateTime.now();
    _controller.add(event);
  }

  /// Get all events visible to a specific player
  List<GameEvent> getEventsForPlayer(GamePlayer player) {
    return eventHistory.where((event) => event.isVisibleTo(player)).toList();
  }

  /// Get recent events visible to a specific player
  /// Get events visible to a specific player
  List<GameEvent> getEventsForGamePlayer(GamePlayer player) {
    return eventHistory.where((event) => event.isVisibleTo(player)).toList();
  }

  List<GameEvent> getRecentEventsForPlayer(
    GamePlayer player, {
    Duration timeWindow = const Duration(minutes: 5),
  }) {
    final cutoffTime = DateTime.now().subtract(timeWindow);
    return eventHistory
        .where(
          (event) =>
              event.timestamp.isAfter(cutoffTime) && event.isVisibleTo(player),
        )
        .toList();
  }

  /// Get events of a specific type visible to a player
  List<GameEvent> getEventsByType(GamePlayer player, GameEventType type) {
    return eventHistory
        .where((event) => event.type == type && event.isVisibleTo(player))
        .toList();
  }

  Future<void> changePhase(GamePhase newPhase) async {
    final oldPhase = currentPhase;
    currentPhase = newPhase;

    final event = PhaseChangeEvent(
      oldPhase: oldPhase,
      newPhase: newPhase,
      dayNumber: dayNumber,
    );
    logger.d(event.toString());
    addEvent(event);
  }

  void startGame() {
    // 移除status设置，由GameEngine管理
    dayNumber = 1;
    currentPhase = GamePhase.night;

    final event = GameStartEvent(
      playerCount: players.length,
      roleDistribution: _getRoleDistribution(),
    );
    logger.d(event.toString());
    addEvent(event);
  }

  void endGame(String winner) {
    // 移除status设置，由GameEngine管理
    this.winner = winner;

    final event = GameEndEvent(
      winner: winner,
      totalDays: dayNumber,
      finalPlayerCount: alivePlayers.length,
      gameStartTime: startTime,
    );
    logger.d(event.toString());
    addEvent(event);
  }

  void playerDeath(GamePlayer player, DeathCause cause) {
    player.setAlive(false);

    final event = DeadEvent(
      victim: player,
      cause: cause,
      dayNumber: dayNumber,
      phase: currentPhase,
    );
    logger.d(event.toString());
    addEvent(event);
  }

  /// Check if game should end
  bool checkGameEnd() {
    logger.d('游戏结束检查: 存活狼人=$aliveWerewolves, 存活好人=$aliveGoodGuys');

    if (alivePlayers.length < 2) {
      logger.w('游戏异常：存活玩家少于2人');
      endGame('Game Error');
      return true;
    }

    final victoryChecker = VictoryConditions(this);
    final winner = victoryChecker.check();

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

  List<GamePlayer> getPlayersByRole(String roleId) {
    return players.where((p) => p.role.roleId == roleId).toList();
  }

  Map<String, int> _getRoleDistribution() {
    final distribution = <String, int>{};
    for (final player in players) {
      distribution[player.role.roleId] =
          (distribution[player.role.roleId] ?? 0) + 1;
    }
    return distribution;
  }

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'startTime': startTime.toIso8601String(),
      // 'config': config.toJson(), // 移除Flutter依赖
      'scenario': {
        'id': scenario.id,
        'name': scenario.name,
        'description': scenario.description,
        'playerCount': scenario.playerCount,
      },
      'currentPhase': currentPhase.name,
      'dayNumber': dayNumber,
      'players': players.map((p) => p.toJson()).toList(),
      'eventHistory': eventHistory.map((e) => e.toJson()).toList(),
      'metadata': metadata,
      'lastUpdateTime': lastUpdateTime?.toIso8601String(),
      'winner': winner,
      'skillEffects': skillEffects,
      'skillUsageCounts': skillUsageCounts,
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    // TODO: 实现GamePlayer的序列化/反序列化
    // final config = AppConfig.fromJson(json['config']); // 移除Flutter依赖
    // final players = (json['players'] as List)
    //     .map((p) => GamePlayer.fromJson(p))
    //     .toList();

    final eventHistory = <GameEvent>[];

    return GameState(
        gameId: json['gameId'],
        // config: config, // 移除Flutter依赖
        scenario: Scenario9Players(), // Placeholder - 使用新的场景类
        players: [], // TODO: 实现玩家序列化
        currentPhase: GamePhase.values.firstWhere(
          (p) => p.name == json['currentPhase'],
        ),
        dayNumber: json['dayNumber'],
        eventHistory: eventHistory,
        metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
        skillEffects: Map<String, dynamic>.from(json['skillEffects'] ?? {}),
        skillUsageCounts: Map<String, int>.from(json['skillUsageCounts'] ?? {}),
      )
      ..lastUpdateTime = json['lastUpdateTime'] != null
          ? DateTime.parse(json['lastUpdateTime'])
          : null
      ..winner = json['winner'];
  }

  void dispose() {
    _controller.close();
  }
}
