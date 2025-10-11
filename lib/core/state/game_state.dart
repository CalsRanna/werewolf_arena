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
import 'package:werewolf_arena/core/domain/value_objects/game_status.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/core/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/core/state/night_action_state.dart';
import 'package:werewolf_arena/core/state/voting_state.dart';
import 'package:werewolf_arena/core/rules/victory_conditions.dart';

/// Game state
class GameState {
  final String gameId;
  final DateTime startTime;
  final AppConfig config;
  final GameScenario scenario;

  GamePhase currentPhase;
  GameStatus status;
  int dayNumber;

  List<Player> players;
  final List<GameEvent> eventHistory;
  final Map<String, dynamic> metadata;

  DateTime? lastUpdateTime;
  String? winner;

  // New state objects
  final NightActionState nightActions;
  final VotingState votingState;

  GameState({
    required this.gameId,
    required this.config,
    required this.scenario,
    required this.players,
    this.currentPhase = GamePhase.night,
    this.status = GameStatus.waiting,
    this.dayNumber = 0,
    List<GameEvent>? eventHistory,
    Map<String, dynamic>? metadata,
    NightActionState? nightActions,
    VotingState? votingState,
  }) : eventHistory = eventHistory ?? [],
       startTime = DateTime.now(),
       metadata = metadata ?? {},
       nightActions = nightActions ?? NightActionState(),
       votingState = votingState ?? VotingState();

  // Getters
  bool get isGameOver => status == GameStatus.ended;
  bool get isNight => currentPhase == GamePhase.night;
  bool get isDay => currentPhase == GamePhase.day;
  bool get isVoting => currentPhase == GamePhase.voting;
  bool get isPlaying => status == GameStatus.playing;

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
    status = GameStatus.playing;
    dayNumber = 1;
    currentPhase = GamePhase.night;

    final event = GameStartEvent(
      playerCount: players.length,
      roleDistribution: _getRoleDistribution(),
    );
    addEvent(event);
  }

  void endGame(String winner) {
    status = GameStatus.ended;
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
      'status': status.name,
      'dayNumber': dayNumber,
      'players': players.map((p) => p.toJson()).toList(),
      'eventHistory': eventHistory.map((e) => e.toJson()).toList(),
      'metadata': metadata,
      'lastUpdateTime': lastUpdateTime?.toIso8601String(),
      'winner': winner,
      'nightActions': nightActions.toJson(),
      'votingState': votingState.toJson(),
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
      status: GameStatus.values.firstWhere((s) => s.name == json['status']),
      dayNumber: json['dayNumber'],
      eventHistory: eventHistory,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      nightActions: NightActionState.fromJson(json['nightActions'] ?? {}, players),
      votingState: VotingState.fromJson(json['votingState'] ?? {}),
    )
      ..lastUpdateTime = json['lastUpdateTime'] != null
          ? DateTime.parse(json['lastUpdateTime'])
          : null
      ..winner = json['winner'];
  }
}
