import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/services/config/config.dart';
import 'package:werewolf_arena/core/scenarios/game_scenario.dart';
import 'package:werewolf_arena/core/scenarios/scenario_9_players.dart'; // 重新导入新的场景类
import 'package:werewolf_arena/services/logging/logger.dart';
import 'package:werewolf_arena/core/events/base/game_event.dart';
import 'package:werewolf_arena/core/events/player_events.dart';
import 'package:werewolf_arena/core/events/phase_events.dart';
import 'package:werewolf_arena/core/events/system_events.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/core/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/core/rules/victory_conditions.dart';

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
  final AppConfig config;
  final GameScenario scenario;

  // 核心游戏状态
  GamePhase currentPhase;
  int dayNumber;

  List<Player> players;
  final List<GameEvent> eventHistory;
  final Map<String, dynamic> metadata;

  DateTime? lastUpdateTime;
  String? winner;

  // 技能效果管理（替代NightActionState和VotingState）
  final Map<String, dynamic> skillEffects; // 存储技能效果状态
  final Map<String, int> skillUsageCounts; // 跟踪技能使用次数

  GameState({
    required this.gameId,
    required this.config,
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

  List<Player> get alivePlayers => players.where((p) => p.isAlive).toList();
  List<Player> get deadPlayers => players.where((p) => !p.isAlive).toList();

  List<Player> get werewolves =>
      players.where((p) => p.role.isWerewolf).toList();
  List<Player> get villagers =>
      players.where((p) => p.role.isVillager).toList();
  List<Player> get gods => players.where((p) => p.role.isGod).toList();

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

  /// 清空临时技能效果（保留持久效果）
  void clearTemporarySkillEffects() {
    final persistentKeys = skillEffects.keys
        .where((key) => key.startsWith('persistent_'))
        .toList();
    
    skillEffects.clear();
    for (final key in persistentKeys) {
      // 恢复持久效果，但这里简化处理
    }
    lastUpdateTime = DateTime.now();
  }

  // Methods
  void addEvent(GameEvent event) {
    eventHistory.add(event);
    lastUpdateTime = DateTime.now();
  }

  /// Get all events visible to a specific player
  List<GameEvent> getEventsForPlayer(Player player) {
    return eventHistory.where((event) => event.isVisibleTo(player)).toList();
  }

  /// Get recent events visible to a specific player
  List<GameEvent> getRecentEventsForPlayer(
    Player player, {
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
  List<GameEvent> getEventsByType(Player player, GameEventType type) {
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
    addEvent(event);
  }

  void playerDeath(Player player, DeathCause cause) {
    player.isAlive = false;

    final event = DeadEvent(
      victim: player,
      cause: cause,
      dayNumber: dayNumber,
      phase: currentPhase,
    );
    addEvent(event);
  }

  /// Check if game should end
  bool checkGameEnd() {
    LoggerUtil.instance.d('游戏结束检查: 存活狼人=$aliveWerewolves, 存活好人=$aliveGoodGuys');
    LoggerUtil.instance.d(
      '存活玩家详情: ${alivePlayers.map((p) => p.formattedName).join(', ')}',
    );

    if (alivePlayers.length < 2) {
      LoggerUtil.instance.w('游戏异常：存活玩家少于2人');
      endGame('Game Error');
      return true;
    }

    final victoryChecker = VictoryConditions(this);
    final winner = victoryChecker.check();

    if (winner != null) {
      endGame(winner);
      return true;
    }

    LoggerUtil.instance.d('游戏继续，未达到结束条件');
    return false;
  }

  Player? getPlayerByName(String playerName) {
    try {
      return players.firstWhere((p) => p.name == playerName);
    } catch (e) {
      return null;
    }
  }

  List<Player> getPlayersByRole(String roleId) {
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
      'config': config.toJson(),
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
    final config = AppConfig.fromJson(json['config']);
    final players = (json['players'] as List)
        .map((p) => Player.fromJson(p))
        .toList();

    final eventHistory = <GameEvent>[];

    return GameState(
      gameId: json['gameId'],
      config: config,
      scenario: Scenario9Players(), // Placeholder - 使用新的场景类
      players: players,
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
}
