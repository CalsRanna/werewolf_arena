import 'dart:io';
import '../player/player.dart';
import '../player/role.dart';
import '../utils/config_loader.dart';
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
  ended; // Ended

  String get displayName {
    switch (this) {
      case GameStatus.waiting:
        return 'Waiting to start';
      case GameStatus.playing:
        return 'Playing';
      case GameStatus.paused:
        return 'Paused';
      case GameStatus.ended:
        return 'Ended';
    }
  }
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

/// Game events
class GameEvent {
  final String eventId;
  final DateTime timestamp;
  final GameEventType type;
  final String description;
  final Map<String, dynamic> data;
  final Player? initiator;
  final Player? target;

  /// Visibility scope of this event
  final EventVisibility visibility;

  /// List of player IDs who can see this event (for playerSpecific visibility)
  final List<String> visibleToPlayerIds;

  /// Role ID that can see this event (for roleSpecific visibility)
  final String? visibleToRole;

  GameEvent({
    required this.eventId,
    required this.type,
    required this.description,
    this.data = const {},
    this.initiator,
    this.target,
    this.visibility = EventVisibility.public,
    this.visibleToPlayerIds = const [],
    this.visibleToRole,
  }) : timestamp = DateTime.now();

  /// Check if this event is visible to a specific player
  bool isVisibleTo(dynamic player) {
    // Extract player properties (support both Player and test objects)
    final playerId = player.playerId as String;
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
        return visibleToPlayerIds.contains(playerId);

      case EventVisibility.dead:
        return !isAlive;
    }
  }

  @override
  String toString() {
    return 'GameEvent($type: $description)';
  }

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'description': description,
      'data': data,
      'initiator': initiator?.playerId,
      'target': target?.playerId,
      'visibility': visibility.name,
      'visibleToPlayerIds': visibleToPlayerIds,
      'visibleToRole': visibleToRole,
    };
  }

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      eventId: json['eventId'],
      type: GameEventType.values.firstWhere((t) => t.name == json['type']),
      description: json['description'],
      data: Map<String, dynamic>.from(json['data']),
      visibility: json['visibility'] != null
          ? EventVisibility.values
              .firstWhere((v) => v.name == json['visibility'])
          : EventVisibility.public,
      visibleToPlayerIds: json['visibleToPlayerIds'] != null
          ? List<String>.from(json['visibleToPlayerIds'])
          : [],
      visibleToRole: json['visibleToRole'],
    );
  }
}

/// Game state
class GameState {
  final String gameId;
  final DateTime startTime;
  final GameConfig config;

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
    required this.players,
    this.currentPhase = GamePhase.night,
    this.status = GameStatus.waiting,
    this.dayNumber = 0,
    List<GameEvent>? eventHistory,
    Map<String, dynamic>? metadata,
  })  : eventHistory = eventHistory ?? [],
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
  int get aliveVillagers =>
      alivePlayers.where((p) => !p.role.isWerewolf).length;

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
        .where((event) =>
            event.timestamp.isAfter(cutoffTime) && event.isVisibleTo(player))
        .toList();
  }

  /// Get events of a specific type visible to a player
  List<GameEvent> getEventsByType(
    Player player,
    GameEventType type,
  ) {
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

    // 等待用户按回车键继续到下一阶段
    await _waitForEnter(_getPhaseChangeMessage(oldPhase, newPhase));
  }

  /// 获取阶段转换提示消息
  String _getPhaseChangeMessage(GamePhase oldPhase, GamePhase newPhase) {
    switch (newPhase) {
      case GamePhase.night:
        return '进入夜晚阶段，按回车键继续...';
      case GamePhase.day:
        return '夜晚结束，进入白天讨论阶段，按回车键继续...';
      case GamePhase.voting:
        return '讨论结束，进入投票阶段，按回车键继续...';
      case GamePhase.ended:
        return '游戏结束，按回车键查看结果...';
    }
  }

  /// 等待用户按回车键继续
  Future<void> _waitForEnter(String message) async {
    while (true) {
      stdout.write(message);

      try {
        final input = stdin.readLineSync() ?? '';
        if (input.trim().isEmpty) {
          // 用户按了回车键（空输入）
          break;
        } else {
          // 用户输入了其他内容，提醒重新输入
          stdout.writeln('请按回车键继续，不要输入其他内容。');
        }
      } catch (e) {
        // 输入流错误，直接退出等待
        stdout.writeln('Input error: $e');
        break;
      }
    }
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
      startTime: startTime,
    );
    addEvent(event);
  }

  void playerDeath(Player player, String cause) {
    player.isAlive = false;

    final event = DeadEvent(
      player: player,
      cause: cause,
      dayNumber: dayNumber,
      phase: currentPhase.name,
    );
    addEvent(event);
  }

  bool checkGameEnd() {
    if (aliveWerewolves == 0) {
      endGame('Good');
      return true;
    }

    if (aliveWerewolves >= aliveVillagers) {
      endGame('Werewolves');
      return true;
    }

    return false;
  }

  Player? getPlayerById(String playerId) {
    try {
      return players.firstWhere((p) => p.playerId == playerId);
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
    setMetadata('tonight_victim', victim?.playerId);
  }

  void setTonightProtected(Player? protected) {
    tonightProtected = protected;
    setMetadata('tonight_protected', protected?.playerId);
  }

  // Night action management methods
  Player? get tonightPoisoned {
    final poisonedId = getMetadata<String>('tonight_poisoned');
    return poisonedId != null ? getPlayerById(poisonedId) : null;
  }

  bool get killCancelled => getMetadata('kill_cancelled') ?? false;

  void setTonightPoisoned(Player? poisoned) {
    setMetadata('tonight_poisoned', poisoned?.playerId);
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
    currentVotes[voter.playerId] = target.playerId;
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

  Player? getVoteTarget() {
    final results = getVoteResults();
    if (results.isEmpty) return null;

    int maxVotes = 0;
    String? targetId;
    for (final entry in results.entries) {
      if (entry.value > maxVotes) {
        maxVotes = entry.value;
        targetId = entry.key;
      }
    }

    if (targetId != null && maxVotes >= requiredVotes) {
      return getPlayerById(targetId);
    }
    return null;
  }

  // Metadata helper methods
  T? getMetadata<T>(String key) => metadata[key] as T?;
  void setMetadata<T>(String key, T value) => metadata[key] = value;
  void removeMetadata(String key) => metadata.remove(key);

  GameState copy() {
    return GameState(
      gameId: gameId,
      config: config,
      players: List<Player>.from(players),
      currentPhase: currentPhase,
      status: status,
      dayNumber: dayNumber,
      eventHistory: List<GameEvent>.from(eventHistory),
      metadata: Map<String, dynamic>.from(metadata),
    )
      ..lastUpdateTime = lastUpdateTime
      ..winner = winner;
  }

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'startTime': startTime.toIso8601String(),
      'config': config.toJson(),
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

  factory GameState.fromJson(Map<String, dynamic> json) {
    final config = GameConfig.fromJson(json['config']);
    final players =
        (json['players'] as List).map((p) => Player.fromJson(p)).toList();
    final eventHistory = (json['eventHistory'] as List)
        .map((e) => GameEvent.fromJson(e))
        .toList();

    return GameState(
      gameId: json['gameId'],
      config: config,
      players: players,
      currentPhase:
          GamePhase.values.firstWhere((p) => p.name == json['currentPhase']),
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
