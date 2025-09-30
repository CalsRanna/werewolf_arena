import 'role.dart';
import '../game/game_state.dart';
import '../game/game_action.dart';
import '../utils/random_helper.dart';
import '../utils/config_loader.dart';

/// Player types
enum PlayerType {
  human, // Human player
  ai, // AI player
}

/// Base player class
abstract class Player {
  final String playerId;
  final String name;
  final Role role;
  final PlayerType type;

  bool isAlive;
  final Map<String, dynamic> privateData;
  final List<GameEvent> actionHistory;

  Player({
    required this.playerId,
    required this.name,
    required this.role,
    required this.type,
    this.isAlive = true,
    Map<String, dynamic>? privateData,
    List<GameEvent>? actionHistory,
  })  : privateData = privateData ?? {},
        actionHistory = actionHistory ?? [];

  // Getters
  bool get isHuman => type == PlayerType.human;
  bool get isAI => type == PlayerType.ai;
  bool get isDead => !isAlive;

  // Role-based getters
  bool get isWerewolf => role.isWerewolf;
  bool get isVillager => role.isVillager;
  bool get isGod => role.isGod;
  bool get isGood => role.isGood;
  bool get isEvil => role.isEvil;

  // Skill management
  int getSkillUses(String skillId) {
    return privateData['skill_uses_$skillId'] ?? 0;
  }

  int getSkillCooldown(String skillId) {
    return privateData['skill_cooldown_$skillId'] ?? 0;
  }

  void useSkill(String skillId) {
    privateData['skill_uses_$skillId'] = getSkillUses(skillId) + 1;
  }

  void setSkillCooldown(String skillId, int cooldown) {
    privateData['skill_cooldown_$skillId'] = cooldown;
  }

  void reduceSkillCooldowns() {
    privateData.forEach((key, value) {
      if (key.startsWith('skill_cooldown_') && value is int && value > 0) {
        privateData[key] = value - 1;
      }
    });
  }

  // Private data management
  T? getPrivateData<T>(String key) {
    return privateData[key] as T?;
  }

  void setPrivateData<T>(String key, T value) {
    privateData[key] = value;
  }

  void removePrivateData(String key) {
    privateData.remove(key);
  }

  bool hasPrivateData(String key) {
    return privateData.containsKey(key);
  }

  // Action management
  void addAction(GameEvent action) {
    actionHistory.add(action);
  }

  List<GameEvent> getActionsByType(GameEventType type) {
    return actionHistory.where((a) => a.type == type).toList();
  }

  List<GameEvent> getRecentActions({int limit = 10}) {
    if (actionHistory.length <= limit) {
      return List<GameEvent>.from(actionHistory);
    }
    return actionHistory.sublist(actionHistory.length - limit);
  }

  // Game actions
  List<GameAction> getAvailableActions(GameState state) {
    return role.getAvailableActions(this, state);
  }

  bool canPerformAction(GameAction action, GameState state) {
    return isAlive && _canPerformAction(action, state);
  }

  bool _canPerformAction(GameAction action, GameState state) {
    // Basic validation - can be enhanced later
    switch (action.type) {
      case ActionType.kill:
        return role.isWerewolf && state.isNight;
      case ActionType.protect:
        return role.roleId == 'guard' && state.isNight;
      case ActionType.investigate:
        return role.roleId == 'seer' && state.isNight;
      case ActionType.heal:
      case ActionType.poison:
        return role.roleId == 'witch' && state.isNight;
      case ActionType.vote:
        return state.isVoting && isAlive;
      case ActionType.speak:
        return state.isDay && isAlive;
      case ActionType.useSkill:
        return isAlive; // Skill-specific validation
    }
  }

  void performAction(GameAction action, GameState state) {
    if (!canPerformAction(action, state)) {
      throw Exception('Cannot perform action: ${action.type}');
    }

    action.execute(state);
    addAction(action.toEvent());
    state.playerAction(this, action.type.name, target: action.target);
  }

  // Communication
  void receiveMessage(String message, {Player? from}) {
    // Store message in private data for AI processing
    final messages = getPrivateData<List<String>>('messages') ?? [];
    messages.add('${from?.name ?? 'System'}: $message');
    setPrivateData('messages', messages);
  }

  List<String> getMessages() {
    return getPrivateData<List<String>>('messages') ?? [];
  }

  void clearMessages() {
    removePrivateData('messages');
  }

  // Knowledge and memory
  void addKnowledge(String key, dynamic value) {
    final knowledge = getPrivateData<Map<String, dynamic>>('knowledge') ?? {};
    knowledge[key] = value;
    setPrivateData('knowledge', knowledge);
  }

  T? getKnowledge<T>(String key) {
    final knowledge = getPrivateData<Map<String, dynamic>>('knowledge') ?? {};
    return knowledge[key] as T?;
  }

  bool hasKnowledge(String key) {
    final knowledge = getPrivateData<Map<String, dynamic>>('knowledge') ?? {};
    return knowledge.containsKey(key);
  }

  // Status and info
  String getStatus() {
    return '$name (${isAlive ? 'Alive' : 'Dead'}) - ${role.name}';
  }

  String getPublicInfo() {
    return '$name: ${isAlive ? 'Alive' : 'Dead'}';
  }

  String getPrivateInfo() {
    return '''
$name ($playerId)
Type: ${type.name}
Status: ${isAlive ? 'Alive' : 'Dead'}
Role: ${role.getRoleInfo()}
Private Data: ${privateData.keys.length} items
Action History: ${actionHistory.length} entries
''';
  }

  // Death handling
  void die(String cause, GameState state) {
    isAlive = false;
    state.playerDeath(this, cause);

    // Handle hunter death
    if (role is HunterRole) {
      setPrivateData('can_shoot', true);
    }
  }

  // Revival (rare cases)
  void revive(GameState state) {
    if (!isAlive) {
      isAlive = true;
      setPrivateData('revived_this_game', true);
    }
  }

  // Serialization
  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'name': name,
      'role': role.toJson(),
      'type': type.name,
      'isAlive': isAlive,
      'privateData': Map<String, dynamic>.from(privateData),
      'actionHistory': actionHistory.map((e) => e.toJson()).toList(),
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    final role = RoleFactory.createRole(json['role']['roleId']);
    final type = PlayerType.values.firstWhere((t) => t.name == json['type']);

    switch (type) {
      case PlayerType.human:
        return HumanPlayer._fromJson(
          playerId: json['playerId'],
          name: json['name'],
          role: role,
          isAlive: json['isAlive'],
          privateData: Map<String, dynamic>.from(json['privateData']),
          actionHistory: (json['actionHistory'] as List)
              .map((e) => GameEventExtension.fromJson(e))
              .toList(),
        );
      case PlayerType.ai:
        throw UnimplementedError(
            'AI player deserialization must be implemented by concrete AI player classes');
    }
  }

  // Copy method
  Player copy() {
    switch (type) {
      case PlayerType.human:
        return HumanPlayer(
          playerId: playerId,
          name: name,
          role: role,
        )
          ..isAlive = isAlive
          ..privateData.addAll(Map<String, dynamic>.from(privateData))
          ..actionHistory.addAll(List<GameEvent>.from(actionHistory));
      case PlayerType.ai:
        throw UnimplementedError(
            'AI player copying must be implemented by concrete subclasses');
    }
  }

  @override
  String toString() {
    return '$name (${role.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Player &&
        other.playerId == playerId &&
        other.name == name &&
        other.role == role;
  }

  @override
  int get hashCode {
    return playerId.hashCode ^ name.hashCode ^ role.hashCode;
  }
}

/// Human player
class HumanPlayer extends Player {
  HumanPlayer({
    required super.playerId,
    required super.name,
    required super.role,
  }) : super(
          type: PlayerType.human,
        );

  @override
  void performAction(GameAction action, GameState state) {
    // Human players need confirmation before performing actions
    super.performAction(action, state);
  }

  factory HumanPlayer._fromJson({
    required String playerId,
    required String name,
    required Role role,
    required bool isAlive,
    required Map<String, dynamic> privateData,
    required List<GameEvent> actionHistory,
  }) {
    return HumanPlayer(
      playerId: playerId,
      name: name,
      role: role,
    )
      ..isAlive = isAlive
      ..privateData.addAll(privateData)
      ..actionHistory.addAll(actionHistory);
  }
}

/// Base AI player class
abstract class AIPlayer extends Player {
  final RandomHelper random;

  AIPlayer({
    required super.playerId,
    required super.name,
    required super.role,
    RandomHelper? random,
  })  : random = random ?? RandomHelper(),
        super(
          type: PlayerType.ai,
        );

  // AI-specific methods
  Future<GameAction?> chooseAction(GameState state) async {
    final availableActions = getAvailableActions(state);
    if (availableActions.isEmpty) {
      return null;
    }

    // Default AI: random selection (to be overridden by specific AI implementations)
    return random.randomChoice(availableActions);
  }

  Future<String> generateStatement(GameState state, String context) async {
    // Default AI: simple response (to be overridden)
    final statements = [
      'I think we need to carefully analyze the current situation.',
      'Based on my observations, I feel something is not quite right.',
      '我们需要更多的信息来做出判断。',
      '我建议大家保持冷静，理性分析。',
    ];
    return random.randomChoice(statements);
  }

  // AI reasoning process
  Future<void> processInformation(GameState state) async {
    // Process game state and update knowledge
    updateKnowledge(state);
  }

  void updateKnowledge(GameState state) {
    // Update AI's knowledge based on current game state
    addKnowledge('last_phase_seen', state.currentPhase);
    addKnowledge('last_day_seen', state.dayNumber);
    addKnowledge('alive_players_count', state.alivePlayers.length);
    addKnowledge('dead_players_count', state.deadPlayers.length);
  }

  // Decision making helpers
  double evaluatePlayerTrustworthiness(Player player, GameState state) {
    // Basic trust evaluation (to be overridden)
    if (player.isWerewolf) return 0.1; // Low trust for werewolves
    if (player.isGod) return 0.8; // High trust for gods
    return 0.5; // Neutral for villagers
  }

  List<Player> getMostSuspiciousPlayers(GameState state) {
    final aliveOthers = state.alivePlayers.where((p) => p != this).toList();
    aliveOthers.sort((a, b) => evaluatePlayerTrustworthiness(a, state)
        .compareTo(evaluatePlayerTrustworthiness(b, state)));
    return aliveOthers;
  }

  List<Player> getMostTrustedPlayers(GameState state) {
    final aliveOthers = state.alivePlayers.where((p) => p != this).toList();
    aliveOthers.sort((a, b) => evaluatePlayerTrustworthiness(b, state)
        .compareTo(evaluatePlayerTrustworthiness(a, state)));
    return aliveOthers;
  }

  factory AIPlayer.fromJson({
    required String playerId,
    required String name,
    required Role role,
    required bool isAlive,
    required Map<String, dynamic> privateData,
    required List<GameEvent> actionHistory,
  }) {
    // Since AIPlayer is abstract, this will be overridden by concrete implementations
    throw UnimplementedError(
        'AIPlayer.fromJson must be implemented by concrete subclasses');
  }
}

// Player factory
class PlayerFactory {
  static Player createPlayer({
    required String name,
    required Role role,
    PlayerType type = PlayerType.ai,
  }) {
    final playerId =
        'player_${DateTime.now().millisecondsSinceEpoch}_${RandomHelper().nextString(8)}';

    switch (type) {
      case PlayerType.human:
        return HumanPlayer(
          playerId: playerId,
          name: name,
          role: role,
        );
      case PlayerType.ai:
        throw UnimplementedError(
            'AI players must use EnhancedAIPlayer from ai_player.dart');
    }
  }

  static List<Player> createPlayersFromConfig(GameConfig config) {
    throw UnimplementedError(
        '请使用 GameEngine 中的 createEnhancedPlayers 方法来创建包含AI服务的玩家');
  }

  static List<String> generatePlayerNames(int count) {
    final names = [
      'Alice',
      'Bob',
      'Charlie',
      'Diana',
      'Eve',
      'Frank',
      'Grace',
      'Henry',
      'Ivy',
      'Jack',
      'Kate',
      'Liam',
      'Mia',
      'Noah',
      'Olivia',
      'Peter',
      'Quinn',
      'Rachel',
      'Sam',
      'Tom',
      'Uma',
      'Victor',
      'Wendy',
      'Xavier',
      'Yara',
      'Zoe'
    ];

    if (count > names.length) {
      // Generate numbered names if we run out
      for (int i = names.length; i < count; i++) {
        names.add('Player${i + 1}');
      }
    }

    return names.sublist(0, count);
  }
}
