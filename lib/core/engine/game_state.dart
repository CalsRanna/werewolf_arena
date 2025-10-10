import 'package:werewolf_arena/core/player/player.dart';
import 'package:werewolf_arena/core/player/role.dart';
import 'package:werewolf_arena/services/config/config.dart';
import 'package:werewolf_arena/core/engine/game_scenario.dart';
import 'package:werewolf_arena/core/rules/scenarios_simple_9.dart';
import 'package:werewolf_arena/services/logging/logger.dart';
import 'game_event.dart';

/// Game phases
enum GamePhase {
  night, // Night phase
  day, // Day phase
  voting, // Voting phase
  ended; // Game ended

  String get displayName {
    switch (this) {
      case GamePhase.night:
        return 'Night';
      case GamePhase.day:
        return 'Day';
      case GamePhase.voting:
        return 'Voting';
      case GamePhase.ended:
        return 'Ended';
    }
  }
}

/// Game status
enum GameStatus {
  waiting, // Waiting to start
  playing, // In game
  paused, // Paused
  ended, // Ended
}

/// Game event types
enum GameEventType {
  gameStart, // Game start
  gameEnd, // Game end
  phaseChange, // Phase change
  playerDeath, // Player death
  playerAction, // Player action
  skillUsed, // Skill used
  voteCast, // Vote cast
  dayBreak, // Daybreak
  nightFall, // Nightfall
}

/// Event visibility scope
enum EventVisibility {
  public, // All players can see
  allWerewolves, // Only werewolves can see
  roleSpecific, // Only specific role can see (e.g., seer's investigation)
  playerSpecific, // Only specific player(s) can see
  dead, // Only dead players can see
}

/// Base class for all structured game events
abstract class GameEvent {
  final String eventId;
  final DateTime timestamp;
  final GameEventType type;
  final Player? initiator;
  final Player? target;
  final EventVisibility visibility;
  final List<String> visibleToPlayerNames;
  final String? visibleToRole;

  GameEvent({
    required this.eventId,
    required this.type,
    this.initiator,
    this.target,
    this.visibility = EventVisibility.public,
    this.visibleToPlayerNames = const [],
    this.visibleToRole,
  }) : timestamp = DateTime.now();

  /// 执行事件逻辑
  void execute(GameState state);

  /// Check if this event is visible to a specific player
  bool isVisibleTo(dynamic player) {
    // Extract player properties (support both Player and test objects)
    final playerName = player.name as String;
    final role = player.role as Role;
    final isAlive = player.isAlive as bool;

    switch (visibility) {
      case EventVisibility.public:
        return true;

      case EventVisibility.allWerewolves:
        return role.isWerewolf;

      case EventVisibility.roleSpecific:
        return visibleToRole != null && role.roleId == visibleToRole;

      case EventVisibility.playerSpecific:
        return visibleToPlayerNames.contains(playerName);

      case EventVisibility.dead:
        return !isAlive;
    }
  }

  @override
  String toString() {
    return 'GameEvent($type: $eventId)';
  }

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'initiator': initiator?.name,
      'target': target?.name,
      'visibility': visibility.name,
      'visibleToPlayerNames': visibleToPlayerNames,
      'visibleToRole': visibleToRole,
    };
  }
}

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
  Player? tonightVictim;
  Player? tonightProtected;

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
  }) : eventHistory = eventHistory ?? [],
       metadata = metadata ?? {},
       startTime = DateTime.now();

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

  /// Check if game should end (屠边规则)
  bool checkGameEnd() {
    // Debug: 打印当前存活情况
    LoggerUtil.instance.d('游戏结束检查: 存活狼人=$aliveWerewolves, 存活好人=$aliveGoodGuys');
    LoggerUtil.instance.d(
      '存活玩家详情: ${alivePlayers.map((p) => p.formattedName).join(', ')}',
    );

    // 确保游戏有活跃玩家
    if (alivePlayers.length < 2) {
      LoggerUtil.instance.w('游戏异常：存活玩家少于2人');
      winner = 'Game Error';
      endGame('Game Error');
      return true;
    }

    // 好人胜利：所有狼人死亡
    if (aliveWerewolves == 0) {
      winner = 'Good';
      endGame('Good');
      LoggerUtil.instance.i('好人阵营获胜！所有狼人已出局\n');
      return true;
    }

    // 狼人胜利条件：屠神（所有神职死亡且有平民）
    final aliveGods = gods.where((p) => p.isAlive).length;
    if (aliveGods == 0 && gods.isNotEmpty && aliveVillagers > 0) {
      // 只有平民和狼人存活，且狼人数量足够
      if (aliveWerewolves >= aliveVillagers) {
        winner = 'Werewolves';
        endGame('Werewolves');
        LoggerUtil.instance.i('狼人阵营获胜！屠神成功（所有神职已出局，狼人占优势）\n');
        return true;
      }
    }

    // 狼人胜利条件：屠民（所有平民死亡且有神职）
    if (aliveVillagers == 0 && villagers.isNotEmpty && aliveGods > 0) {
      // 只有神职和狼人存活，且狼人数量足够
      if (aliveWerewolves >= aliveGods) {
        winner = 'Werewolves';
        endGame('Werewolves');
        LoggerUtil.instance.i('狼人阵营获胜！屠民成功（所有平民已出局，狼人占优势）\n');
        return true;
      }
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

  void setTonightVictim(Player? victim) {
    tonightVictim = victim;
    setMetadata('tonight_victim', victim?.name);
  }

  void setTonightProtected(Player? protected) {
    tonightProtected = protected;
    setMetadata('tonight_protected', protected?.name);
  }

  // Night action management methods
  Player? get tonightPoisoned {
    final poisonedId = getMetadata<String>('tonight_poisoned');
    return poisonedId != null ? getPlayerByName(poisonedId) : null;
  }

  bool get killCancelled => getMetadata('kill_cancelled') ?? false;

  void setTonightPoisoned(Player? poisoned) {
    setMetadata('tonight_poisoned', poisoned?.name);
  }

  void cancelTonightKill() {
    setMetadata('kill_cancelled', true);
  }

  void clearNightActions() {
    removeMetadata('tonight_victim');
    removeMetadata('tonight_protected');
    removeMetadata('tonight_poisoned');
    removeMetadata('kill_cancelled');
  }

  // Voting management methods
  Map<String, String> get votes => getMetadata('votes') ?? {};
  int get totalVotes => votes.length;
  int get requiredVotes => (alivePlayers.length / 2).ceil();

  void addVote(Player voter, Player target) {
    final currentVotes = votes;
    currentVotes[voter.name] = target.name;
    setMetadata('votes', currentVotes);
  }

  void clearVotes() {
    removeMetadata('votes');
  }

  Map<String, int> getVoteResults() {
    final results = <String, int>{};
    for (final vote in votes.values) {
      results[vote] = (results[vote] ?? 0) + 1;
    }
    return results;
  }

  /// Get vote target - returns the player with most votes
  /// If there's a tie, returns null (indicating need for PK)
  Player? getVoteTarget() {
    final results = getVoteResults();
    if (results.isEmpty) return null;

    int maxVotes = 0;
    List<String> tiedPlayers = [];

    for (final entry in results.entries) {
      if (entry.value > maxVotes) {
        maxVotes = entry.value;
        tiedPlayers = [entry.key];
      } else if (entry.value == maxVotes) {
        tiedPlayers.add(entry.key);
      }
    }

    // 如果有平票且票数相同的人超过1个,返回null表示需要PK
    if (tiedPlayers.length > 1) {
      return null;
    }

    // 得票最多的玩家出局
    if (tiedPlayers.isNotEmpty && maxVotes > 0) {
      return getPlayerByName(tiedPlayers.first);
    }
    return null;
  }

  /// Get tied players for PK
  List<Player> getTiedPlayers() {
    final results = getVoteResults();
    if (results.isEmpty) return [];

    int maxVotes = 0;
    List<String> tiedPlayerNames = [];

    for (final entry in results.entries) {
      if (entry.value > maxVotes) {
        maxVotes = entry.value;
        tiedPlayerNames = [entry.key];
      } else if (entry.value == maxVotes) {
        tiedPlayerNames.add(entry.key);
      }
    }

    // 只有当有2个或以上玩家平票时才返回
    if (tiedPlayerNames.length > 1) {
      return tiedPlayerNames
          .map((name) => getPlayerByName(name))
          .whereType<Player>()
          .toList();
    }
    return [];
  }

  // Metadata helper methods
  T? getMetadata<T>(String key) => metadata[key] as T?;
  void setMetadata<T>(String key, T value) => metadata[key] = value;
  void removeMetadata(String key) => metadata.remove(key);

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'startTime': startTime.toIso8601String(),
      'config': config.toJson(),
      'scenario': scenario.toJson(),
      'currentPhase': currentPhase.name,
      'status': status.name,
      'dayNumber': dayNumber,
      'players': players.map((p) => p.toJson()).toList(),
      'eventHistory': eventHistory.map((e) => e.toJson()).toList(),
      'metadata': metadata,
      'lastUpdateTime': lastUpdateTime?.toIso8601String(),
      'winner': winner,
    };
  }

  // TODO: Implement proper event deserialization with event factory
  factory GameState.fromJson(Map<String, dynamic> json) {
    final config = AppConfig.fromJson(json['config']);
    // 注意：场景不再从JSON反序列化，而是在游戏运行时设置
    final players = (json['players'] as List)
        .map((p) => Player.fromJson(p))
        .toList();

    // Skip event history deserialization for now - will implement event factory later
    final eventHistory = <GameEvent>[];

    return GameState(
        gameId: json['gameId'],
        config: config,
        scenario: Simple9PlayersScenario(), // 临时使用默认场景
        players: players,
        currentPhase: GamePhase.values.firstWhere(
          (p) => p.name == json['currentPhase'],
        ),
        status: GameStatus.values.firstWhere((s) => s.name == json['status']),
        dayNumber: json['dayNumber'],
        eventHistory: eventHistory,
        metadata: Map<String, dynamic>.from(json['metadata']),
      )
      ..lastUpdateTime = json['lastUpdateTime'] != null
          ? DateTime.parse(json['lastUpdateTime'])
          : null
      ..winner = json['winner'];
  }
}
