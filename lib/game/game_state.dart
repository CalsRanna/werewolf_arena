import 'dart:io';
import '../player/player.dart';
import '../player/judge.dart';
import '../utils/config_loader.dart';

/// Game phases
enum GamePhase {
  night, // Night phase
  day, // Day phase
  voting, // Voting phase
  ended, // Game ended
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

/// Game events
class GameEvent {
  final String eventId;
  final DateTime timestamp;
  final GameEventType type;
  final String description;
  final Map<String, dynamic> data;
  final Player? initiator;
  final Player? target;

  GameEvent({
    required this.eventId,
    required this.type,
    required this.description,
    this.data = const {},
    this.initiator,
    this.target,
  }) : timestamp = DateTime.now();

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
    };
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

  // Judge and speech history
  late final Judge judge;

  GameState({
    required this.gameId,
    required this.config,
    required this.players,
    this.currentPhase = GamePhase.night,
    this.status = GameStatus.waiting,
    this.dayNumber = 0,
    List<GameEvent>? eventHistory,
    Map<String, dynamic>? metadata,
    Judge? judge,
  })  : eventHistory = eventHistory ?? [],
        metadata = metadata ?? {},
        startTime = DateTime.now() {
    // Initialize judge, create new one if not provided
    this.judge = judge ?? Judge(gameId: gameId);
  }

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

  /// Record player speech to judge system
  void recordPlayerSpeech(Player player, String message) {
    judge.recordSpeech(
      playerId: player.playerId,
      playerName: player.name,
      roleName: player.role.name,
      message: message,
      phase: _getPhaseDisplayName(currentPhase),
      dayNumber: dayNumber,
    );
  }

  /// Get speech history for LLM context
  String getSpeechHistoryForContext({int? limit}) {
    return judge.getSpeechHistoryText(limit: limit);
  }

  /// Get speech history for current phase
  String getCurrentPhaseSpeechHistory() {
    return judge.getSpeechHistoryText(
      fromDay: dayNumber,
      phase: _getPhaseDisplayName(currentPhase),
    );
  }

  /// Get phase display name
  String _getPhaseDisplayName(GamePhase phase) {
    switch (phase) {
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

  Future<void> changePhase(GamePhase newPhase) async {
    final oldPhase = currentPhase;
    currentPhase = newPhase;

    addEvent(GameEvent(
      eventId: 'phase_change_${DateTime.now().millisecondsSinceEpoch}',
      type: GameEventType.phaseChange,
      description: 'Game phase changed from ${oldPhase.name} to ${newPhase.name}',
      data: {
        'oldPhase': oldPhase.name,
        'newPhase': newPhase.name,
        'dayNumber': dayNumber,
      },
    ));

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

    addEvent(GameEvent(
      eventId: 'game_start_${DateTime.now().millisecondsSinceEpoch}',
      type: GameEventType.gameStart,
      description: 'Game started with ${players.length} players',
      data: {
        'playerCount': players.length,
        'roleDistribution': _getRoleDistribution(),
      },
    ));
  }

  void endGame(String winner) {
    status = GameStatus.ended;
    this.winner = winner;

    addEvent(GameEvent(
      eventId: 'game_end_${DateTime.now().millisecondsSinceEpoch}',
      type: GameEventType.gameEnd,
      description: 'Game ended. Winner: $winner',
      data: {
        'winner': winner,
        'duration': DateTime.now().difference(startTime).inMilliseconds,
        'totalDays': dayNumber,
        'finalPlayerCount': alivePlayers.length,
      },
    ));
  }

  void playerDeath(Player player, String cause) {
    player.isAlive = false;

    addEvent(GameEvent(
      eventId:
          'player_death_${player.playerId}_${DateTime.now().millisecondsSinceEpoch}',
      type: GameEventType.playerDeath,
      description: '${player.name} died: $cause',
      initiator: player,
      data: {
        'cause': cause,
        'wasAlive': true,
        'dayNumber': dayNumber,
        'phase': currentPhase.name,
      },
    ));
  }

  void playerAction(Player player, String action, {Player? target}) {
    addEvent(GameEvent(
      eventId:
          'player_action_${player.playerId}_${DateTime.now().millisecondsSinceEpoch}',
      type: GameEventType.playerAction,
      description:
          '${player.name} performed action: $action${target != null ? ' on ${target.name}' : ''}',
      initiator: player,
      target: target,
      data: {
        'action': action,
        'targetId': target?.playerId,
        'dayNumber': dayNumber,
        'phase': currentPhase.name,
      },
    ));
  }

  void skillUsed(Player player, String skill, {Player? target}) {
    addEvent(GameEvent(
      eventId:
          'skill_used_${player.playerId}_${DateTime.now().millisecondsSinceEpoch}',
      type: GameEventType.skillUsed,
      description:
          '${player.name} used skill: $skill${target != null ? ' on ${target.name}' : ''}',
      initiator: player,
      target: target,
      data: {
        'skill': skill,
        'targetId': target?.playerId,
        'dayNumber': dayNumber,
        'phase': currentPhase.name,
      },
    ));
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
  }

  void setTonightProtected(Player? protected) {
    tonightProtected = protected;
  }

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
        .map((e) => GameEventExtension.fromJson(e))
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

// Extension methods for GameEvent
extension GameEventExtension on GameEvent {
  static GameEvent fromJson(Map<String, dynamic> json) {
    final event = GameEvent(
      eventId: json['eventId'],
      type: GameEventType.values.firstWhere((t) => t.name == json['type']),
      description: json['description'],
      data: Map<String, dynamic>.from(json['data']),
    );
    // Set the timestamp manually since it's not a constructor parameter
    return event;
  }
}

// Extension for GamePhase
extension GamePhaseExtension on GamePhase {
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

// Extension for GameStatus
extension GameStatusExtension on GameStatus {
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
