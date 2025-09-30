import '../player/player.dart';
import '../player/judge.dart';
import '../utils/config_loader.dart';
import '../utils/game_logger.dart';

/// 游戏阶段
enum GamePhase {
  night, // 夜晚阶段
  day, // 白天阶段
  voting, // 投票阶段
  ended, // 游戏结束
}

/// 游戏状态
enum GameStatus {
  waiting, // 等待开始
  playing, // 游戏中
  paused, // 暂停
  ended, // 已结束
}

/// 游戏事件类型
enum GameEventType {
  gameStart, // 游戏开始
  gameEnd, // 游戏结束
  phaseChange, // 阶段变化
  playerDeath, // 玩家死亡
  playerAction, // 玩家行动
  skillUsed, // 技能使用
  voteCast, // 投票
  dayBreak, // 天亮
  nightFall, // 天黑
}

/// 游戏事件
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

/// 游戏状态
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

  // 法官和发言历史
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
    // 初始化法官，如果没有提供则创建新的
    this.judge = judge ??
        Judge(
          gameId: gameId,
          logger: GameLogger(config.loggingConfig),
        );
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

  /// 记录玩家发言到法官系统
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

  /// 获取发言历史用于LLM上下文
  String getSpeechHistoryForContext({int? limit}) {
    return judge.getSpeechHistoryText(limit: limit);
  }

  /// 获取当前阶段的发言历史
  String getCurrentPhaseSpeechHistory() {
    return judge.getSpeechHistoryText(
      fromDay: dayNumber,
      phase: _getPhaseDisplayName(currentPhase),
    );
  }

  /// 获取阶段显示名称
  String _getPhaseDisplayName(GamePhase phase) {
    switch (phase) {
      case GamePhase.night:
        return '夜晚';
      case GamePhase.day:
        return '白天';
      case GamePhase.voting:
        return '投票';
      case GamePhase.ended:
        return '结束';
    }
  }

  void changePhase(GamePhase newPhase) {
    final oldPhase = currentPhase;
    currentPhase = newPhase;

    addEvent(GameEvent(
      eventId: 'phase_change_${DateTime.now().millisecondsSinceEpoch}',
      type: GameEventType.phaseChange,
      description: '游戏阶段从 ${oldPhase.name} 切换到 ${newPhase.name}',
      data: {
        'oldPhase': oldPhase.name,
        'newPhase': newPhase.name,
        'dayNumber': dayNumber,
      },
    ));
  }

  void startGame() {
    status = GameStatus.playing;
    dayNumber = 1;
    currentPhase = GamePhase.night;

    addEvent(GameEvent(
      eventId: 'game_start_${DateTime.now().millisecondsSinceEpoch}',
      type: GameEventType.gameStart,
      description: '游戏开始，玩家数量：${players.length}',
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
      description: '游戏结束。获胜者：$winner',
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
      description: '${player.name} 死亡：$cause',
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
          '${player.name} 执行了动作：$action${target != null ? ' 对 ${target.name}' : ''}',
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
          '${player.name} 使用了技能：$skill${target != null ? ' 对 ${target.name}' : ''}',
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
      endGame('好人');
      return true;
    }

    if (aliveWerewolves >= aliveVillagers) {
      endGame('狼人');
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
        return '夜晚';
      case GamePhase.day:
        return '白天';
      case GamePhase.voting:
        return '投票';
      case GamePhase.ended:
        return '结束';
    }
  }
}

// Extension for GameStatus
extension GameStatusExtension on GameStatus {
  String get displayName {
    switch (this) {
      case GameStatus.waiting:
        return '等待开始';
      case GameStatus.playing:
        return '游戏中';
      case GameStatus.paused:
        return '暂停';
      case GameStatus.ended:
        return '已结束';
    }
  }
}
