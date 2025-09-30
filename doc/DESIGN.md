# 狼人杀LLM游戏详细设计文档

## 1. 系统架构设计

### 1.1 整体架构图
```
┌─────────────────────────────────────────────────────────────┐
│                    用户接口层 (UI Layer)                      │
├─────────────────────────────────────────────────────────────┤
│  ConsoleUI  │  DisplayManager  │  InputHandler  │  Logger   │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    游戏逻辑层 (Game Layer)                    │
├─────────────────────────────────────────────────────────────┤
│ GameEngine  │  GameState  │  PhaseManager  │  RoleSystem   │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    玩家管理层 (Player Layer)                  │
├─────────────────────────────────────────────────────────────┤
│   Player    │  AIPlayer   │   RoleFactory  │  ActionSystem │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    LLM服务层 (LLM Layer)                      │
├─────────────────────────────────────────────────────────────┤
│ LLMService  │  PromptManager  │  ResponseParser  │  Cache   │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    基础设施层 (Infrastructure Layer)           │
├─────────────────────────────────────────────────────────────┤
│   Config    │   Logger    │   RandomHelper  │  Validator   │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 核心组件职责

#### 1.2.1 游戏引擎 (GameEngine)
- 游戏生命周期管理
- 游戏流程控制
- 事件分发和处理
- 错误处理和恢复

#### 1.2.2 状态管理 (GameState)
- 游戏状态维护
- 历史记录存储
- 状态验证和检查
- 序列化和反序列化

#### 1.2.3 LLM服务 (LLMService)
- API调用管理
- 响应缓存
- 错误重试机制
- 成本控制

## 2. 数据结构设计

### 2.1 游戏状态数据结构

```dart
// 游戏状态
class GameState {
  final String gameId;
  final DateTime startTime;
  GamePhase currentPhase;
  int dayNumber;
  List<Player> players;
  GameStatus status;
  List<GameEvent> eventHistory;
  Map<String, dynamic> metadata;

  bool get isGameOver => status == GameStatus.ended;
  bool get isNight => currentPhase == GamePhase.night;
  bool get isDay => currentPhase == GamePhase.day;
}

// 游戏阶段
enum GamePhase {
  night,    // 夜晚阶段
  day,      // 白天阶段
  voting,   // 投票阶段
  ended     // 游戏结束
}

// 游戏状态
enum GameStatus {
  waiting,  // 等待开始
  playing,  // 游戏中
  paused,   // 暂停
  ended     // 已结束
}

// 游戏事件
class GameEvent {
  final String eventId;
  final DateTime timestamp;
  final GameEventType type;
  final String description;
  final Map<String, dynamic> data;
  final Player? initiator;
  final Player? target;
}
```

### 2.2 玩家数据结构

```dart
// 玩家基类
abstract class Player {
  final String playerId;
  final String name;
  final Role role;
  final bool isAlive;
  final PlayerType type;
  final List<GameEvent> actionHistory;
  final Map<String, dynamic> privateData;

  bool get isHuman => type == PlayerType.human;
  bool get isAI => type == PlayerType.ai;

  void performAction(GameAction action);
  void receiveMessage(String message);
  String getPublicInfo();
  String getPrivateInfo();
}

// AI玩家
class AIPlayer extends Player {
  final LLMService llmService;
  final Personality personality;
  final RolePrompt rolePrompt;
  final List<String> conversationHistory;
  final KnowledgeBase knowledge;

  Future<GameAction> generateAction(GameContext context);
  Future<String> generateStatement(GameContext context);
  void updateKnowledge(GameEvent event);
}

// 角色定义
abstract class Role {
  final String roleId;
  final String name;
  final RoleType type;
  final String description;
  final List<Skill> skills;
  final RoleAlignment alignment;

  bool get isWerewolf => type == RoleType.werewolf;
  bool get isVillager => type == RoleType.villager;
  bool get isGod => type == RoleType.god;

  List<GameAction> getAvailableActions(GameState state);
  bool canUseSkill(Skill skill, GameState state);
}

// 角色类型
enum RoleType {
  werewolf,  // 狼人
  villager,  // 村民
  god,       // 神职
}

// 角色阵营
enum RoleAlignment {
  good,      // 好人阵营
  evil,      // 狼人阵营
  neutral,   // 中立阵营
}
```

### 2.3 动作系统数据结构

```dart
// 游戏动作
abstract class GameAction {
  final String actionId;
  final Player actor;
  final List<Player> targets;
  final ActionType type;
  final Map<String, dynamic> parameters;

  bool validate(GameState state);
  void execute(GameState state);
  GameEvent toEvent();
}

// 动作类型
enum ActionType {
  kill,          // 击杀
  protect,       // 保护
  investigate,   // 查验
  heal,          // 救治
  poison,        // 毒杀
  vote,          // 投票
  speak,         // 发言
  useSkill,      // 使用技能
}

// 具体动作示例
class KillAction extends GameAction {
  final Player victim;

  @override
  void execute(GameState state) {
    victim.isAlive = false;
    state.addEvent(GameEvent(
      type: GameEventType.playerDeath,
      description: '${actor.name} 击杀了 ${victim.name}',
      initiator: actor,
      target: victim,
    ));
  }

  @override
  bool validate(GameState state) {
    return actor.isAlive &&
           victim.isAlive &&
           actor.role.isWerewolf &&
           state.currentPhase == GamePhase.night;
  }
}
```

### 2.4 LLM相关数据结构

```dart
// 角色提示词
class RolePrompt {
  final String roleName;
  final String systemPrompt;
  final String personalityPrompt;
  final String knowledgePrompt;
  final String strategyPrompt;
  final List<String> examples;

  String getFullPrompt() {
    return '''
$systemPrompt

$personalityPrompt

$knowledgePrompt

$strategyPrompt

示例对话：
${examples.join('\n\n')}
''';
  }
}

// AI性格
class Personality {
  final double aggressiveness;     // 激进度 0-1
  final double logicThinking;      // 逻辑性 0-1
  final double cooperativeness;    // 合作性 0-1
  final double honesty;           // 诚实度 0-1
  final double expressiveness;     // 表现力 0-1

  String getPersonalityDescription() {
    return '''
性格特征：
- 激进度: ${_getTraitDescription(aggressiveness)}
- 逻辑性: ${_getTraitDescription(logicThinking)}
- 合作性: ${_getTraitDescription(cooperativeness)}
- 诚实度: ${_getTraitDescription(honesty)}
- 表现力: ${_getTraitDescription(expressiveness)}
''';
  }

  String _getTraitDescription(double value) {
    if (value < 0.2) return '很低';
    if (value < 0.4) return '较低';
    if (value < 0.6) return '中等';
    if (value < 0.8) return '较高';
    return '很高';
  }
}

// LLM响应
class LLMResponse {
  final String content;
  final Map<String, dynamic> parsedData;
  final List<GameAction> actions;
  final String statement;
  final bool isValid;
  final List<String> errors;

  static LLMResponse fromJson(Map<String, dynamic> json) {
    return LLMResponse(
      content: json['content'] ?? '',
      parsedData: json['parsedData'] ?? {},
      actions: _parseActions(json['actions'] ?? []),
      statement: json['statement'] ?? '',
      isValid: json['isValid'] ?? false,
      errors: List<String>.from(json['errors'] ?? []),
    );
  }
}
```

## 3. 游戏流程设计

### 3.1 主游戏循环

```dart
class GameEngine {
  final GameState state;
  final PhaseManager phaseManager;
  final RuleEngine ruleEngine;
  final EventDispatcher eventDispatcher;

  Future<void> startGame() async {
    // 初始化游戏
    await _initializeGame();

    // 主游戏循环
    while (!state.isGameOver) {
      switch (state.currentPhase) {
        case GamePhase.night:
          await _runNightPhase();
          break;
        case GamePhase.day:
          await _runDayPhase();
          break;
        case GamePhase.voting:
          await _runVotingPhase();
          break;
        case GamePhase.ended:
          await _endGame();
          break;
      }

      // 检查游戏结束条件
      if (_checkGameEnd()) {
        state.currentPhase = GamePhase.ended;
      }
    }
  }

  Future<void> _runNightPhase() async {
    state.dayNumber++;
    state.currentPhase = GamePhase.night;

    // 夜晚阶段顺序
    final nightActions = [
      NightAction.werewolfKill,
      NightAction.guardProtect,
      NightAction.seerCheck,
      NightAction.witchHeal,
      NightAction.witchPoison,
    ];

    for (final actionType in nightActions) {
      await _processNightAction(actionType);
    }

    // 处理夜晚结果
    await _resolveNightActions();
  }

  Future<void> _runDayPhase() async {
    state.currentPhase = GamePhase.day;

    // 公布夜晚结果
    await _announceNightResults();

    // 讨论阶段
    await _runDiscussionPhase();

    // 进入投票阶段
    state.currentPhase = GamePhase.voting;
  }
}
```

### 3.2 阶段管理器

```dart
class PhaseManager {
  final List<PhaseHandler> handlers;

  Future<void> handlePhase(GamePhase phase, GameState state) async {
    final handler = handlers.firstWhere(
      (h) => h.canHandle(phase),
      orElse: () => throw Exception('No handler for phase $phase')
    );

    await handler.handle(state);
  }
}

abstract class PhaseHandler {
  bool canHandle(GamePhase phase);
  Future<void> handle(GameState state);
}

class NightPhaseHandler implements PhaseHandler {
  @override
  bool canHandle(GamePhase phase) => phase == GamePhase.night;

  @override
  Future<void> handle(GameState state) async {
    final nightManager = NightActionManager(state);

    // 1. 狼人行动
    await nightManager.processWerewolfActions();

    // 2. 守卫行动
    await nightManager.processGuardActions();

    // 3. 预言家行动
    await nightManager.processSeerActions();

    // 4. 女巫行动
    await nightManager.processWitchActions();

    // 5. 结算夜晚行动
    await nightManager.resolveNightActions();
  }
}
```

## 4. 角色系统设计

### 4.1 角色工厂

```dart
class RoleFactory {
  static Role createRole(RoleType type, String roleId) {
    switch (type) {
      case RoleType.werewolf:
        return WerewolfRole(roleId);
      case RoleType.villager:
        return VillagerRole(roleId);
      case RoleType.god:
        return _createGodRole(roleId);
      default:
        throw Exception('Unknown role type: $type');
    }
  }

  static Role _createGodRole(String roleId) {
    // 根据配置创建不同的神职角色
    final config = GameConfig.current;
    final godType = config.getGodRoleType(roleId);

    switch (godType) {
      case GodRoleType.seer:
        return SeerRole(roleId);
      case GodRoleType.witch:
        return WitchRole(roleId);
      case GodRoleType.hunter:
        return HunterRole(roleId);
      case GodRoleType.guard:
        return GuardRole(roleId);
      default:
        throw Exception('Unknown god role type: $godType');
    }
  }
}
```

### 4.2 具体角色实现

```dart
// 狼人角色
class WerewolfRole extends Role {
  WerewolfRole(String roleId) : super(
    roleId: roleId,
    name: '狼人',
    type: RoleType.werewolf,
    alignment: RoleAlignment.evil,
    description: '每晚可以击杀一名玩家',
    skills: [KillSkill()],
  );

  @override
  List<GameAction> getAvailableActions(GameState state) {
    if (!state.isNight) return [];

    final werewolves = state.players.where((p) =>
      p.isAlive && p.role.isWerewolf
    ).toList();

    final alivePlayers = state.players.where((p) =>
      p.isAlive && !p.role.isWerewolf
    ).toList();

    return alivePlayers.map((target) => KillAction(
      actor: werewolves.first,
      target: target,
    )).toList();
  }
}

// 预言家角色
class SeerRole extends Role {
  SeerRole(String roleId) : super(
    roleId: roleId,
    name: '预言家',
    type: RoleType.god,
    alignment: RoleAlignment.good,
    description: '每晚可以查验一名玩家身份',
    skills: [InvestigateSkill()],
  );

  @override
  List<GameAction> getAvailableActions(GameState state) {
    if (!state.isNight) return [];

    final otherPlayers = state.players.where((p) =>
      p.isAlive && p.playerId != state.currentPlayer?.playerId
    ).toList();

    return otherPlayers.map((target) => InvestigateAction(
      actor: state.currentPlayer!,
      target: target,
    )).toList();
  }
}

// 女巫角色
class WitchRole extends Role {
  WitchRole(String roleId) : super(
    roleId: roleId,
    name: '女巫',
    type: RoleType.god,
    alignment: RoleAlignment.good,
    description: '拥有解药和毒药各一瓶',
    skills: [HealSkill(), PoisonSkill()],
  );

  @override
  List<GameAction> getAvailableActions(GameState state) {
    if (!state.isNight) return [];

    final actions = <GameAction>[];
    final witch = state.currentPlayer!;

    // 检查解药
    if (witch.privateData['hasAntidote'] == true) {
      final tonightVictim = witch.privateData['tonightVictim'] as Player?;
      if (tonightVictim != null) {
        actions.add(HealAction(
          actor: witch,
          target: tonightVictim,
        ));
      }
    }

    // 检查毒药
    if (witch.privateData['hasPoison'] == true) {
      final otherPlayers = state.players.where((p) =>
        p.isAlive && p.playerId != witch.playerId
      ).toList();

      actions.addAll(otherPlayers.map((target) => PoisonAction(
        actor: witch,
        target: target,
      )));
    }

    return actions;
  }
}
```

### 4.3 技能系统

```dart
abstract class Skill {
  final String skillId;
  final String name;
  final String description;
  final int cooldown;
  final int maxUses;

  bool canUse(Player player, GameState state);
  void execute(Player player, GameAction action, GameState state);
}

class KillSkill extends Skill {
  KillSkill() : super(
    skillId: 'kill',
    name: '击杀',
    description: '击杀一名玩家',
    cooldown: 0,
    maxUses: -1, // 无限使用
  );

  @override
  bool canUse(Player player, GameState state) {
    return player.isAlive &&
           player.role.isWerewolf &&
           state.isNight;
  }

  @override
  void execute(Player player, GameAction action, GameState state) {
    if (action is KillAction) {
      action.execute(state);
    }
  }
}

class InvestigateSkill extends Skill {
  InvestigateSkill() : super(
    skillId: 'investigate',
    name: '查验',
    description: '查验一名玩家身份',
    cooldown: 0,
    maxUses: -1,
  );

  @override
  bool canUse(Player player, GameState state) {
    return player.isAlive &&
           player.role is SeerRole &&
           state.isNight;
  }

  @override
  void execute(Player player, GameAction action, GameState state) {
    if (action is InvestigateAction) {
      action.execute(state);

      // 将查验结果添加到玩家私有数据
      final target = action.target;
      final isWerewolf = target.role.isWerewolf;

      player.privateData['investigation_results'] ??= [];
      player.privateData['investigation_results'].add({
        'target': target.name,
        'result': isWerewolf ? '狼人' : '好人',
        'night': state.dayNumber,
      });
    }
  }
}
```

## 5. LLM集成设计

### 5.1 LLM服务接口

```dart
abstract class LLMService {
  Future<LLMResponse> generateResponse({
    required String systemPrompt,
    required String userPrompt,
    required Map<String, dynamic> context,
    double temperature = 0.7,
    int maxTokens = 1000,
  });

  Future<LLMResponse> generateAction({
    required Player player,
    required GameState state,
    required RolePrompt rolePrompt,
  });

  Future<String> generateStatement({
    required Player player,
    required GameState state,
    required RolePrompt rolePrompt,
    required String prompt,
  });
}

class OpenAIService implements LLMService {
  final String apiKey;
  final String model;
  final HttpClient client;
  final ResponseCache cache;

  @override
  Future<LLMResponse> generateResponse({
    required String systemPrompt,
    required String userPrompt,
    required Map<String, dynamic> context,
    double temperature = 0.7,
    int maxTokens = 1000,
  }) async {
    final request = {
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
    };

    try {
      final response = await _makeAPIRequest(request);
      return LLMResponse.fromJson(response);
    } catch (e) {
      // 重试逻辑
      return await _retryRequest(request, maxRetries: 3);
    }
  }

  Future<Map<String, dynamic>> _makeAPIRequest(Map<String, dynamic> request) async {
    // 实现API调用逻辑
    // ...
  }
}
```

### 5.2 提示词管理器

```dart
class PromptManager {
  final Map<String, RolePrompt> rolePrompts;
  final Map<String, String> systemPrompts;
  final Map<String, List<String>> examples;

  Future<String> generateActionPrompt({
    required Player player,
    required GameState state,
    required List<GameAction> availableActions,
  }) async {
    final rolePrompt = rolePrompts[player.role.roleId]!;
    final context = _buildContext(player, state);

    return '''
${rolePrompt.getFullPrompt()}

当前游戏状态：
$context

可用的动作：
${_formatActions(availableActions)}

请选择你的动作，并解释原因。以JSON格式返回：
{
  "action": "动作ID",
  "target": "目标玩家ID（可选）",
  "reasoning": "推理过程",
  "statement": "公开陈述"
}
''';
  }

  Future<String> generateStatementPrompt({
    required Player player,
    required GameState state,
    required String situation,
  }) async {
    final rolePrompt = rolePrompts[player.role.roleId]!;
    final context = _buildContext(player, state);

    return '''
${rolePrompt.getFullPrompt()}

当前游戏状态：
$context

当前情况：
$situation

请根据你的角色和性格，发表适当的言论。
''';
  }

  String _buildContext(Player player, GameState state) {
    return '''
游戏第 ${state.dayNumber} 天
当前阶段：${state.currentPhase.name}
存活玩家：${state.players.where((p) => p.isAlive).map((p) => p.name).join(', ')}
你的状态：${player.isAlive ? '存活' : '死亡'}
你的角色：${player.role.name}
''';
  }

  String _formatActions(List<GameAction> actions) {
    return actions.map((action) {
      return '- ${action.type.name}: ${action.description}';
    }).join('\n');
  }
}
```

### 5.3 响应解析器

```dart
class ResponseParser {
  static LLMResponse parseActionResponse(String response, Player player) {
    try {
      final jsonData = json.decode(response);

      // 验证必要字段
      if (!jsonData.containsKey('action')) {
        return LLMResponse.invalid(['Missing action field']);
      }

      // 解析动作
      final actionType = _parseActionType(jsonData['action']);
      final target = jsonData['target'] != null ?
          _findTargetById(jsonData['target'], player) : null;

      // 构建动作对象
      final action = _buildAction(actionType, player, target, jsonData);

      return LLMResponse(
        content: response,
        parsedData: jsonData,
        actions: [action],
        statement: jsonData['statement'] ?? '',
        isValid: true,
        errors: [],
      );
    } catch (e) {
      return LLMResponse.invalid(['Parse error: $e']);
    }
  }

  static ActionType _parseActionType(String actionString) {
    switch (actionString.toLowerCase()) {
      case 'kill':
        return ActionType.kill;
      case 'protect':
        return ActionType.protect;
      case 'investigate':
        return ActionType.investigate;
      case 'heal':
        return ActionType.heal;
      case 'poison':
        return ActionType.poison;
      case 'vote':
        return ActionType.vote;
      default:
        throw Exception('Unknown action type: $actionString');
    }
  }

  static GameAction _buildAction(
    ActionType type,
    Player actor,
    Player? target,
    Map<String, dynamic> data,
  ) {
    switch (type) {
      case ActionType.kill:
        return KillAction(actor: actor, target: target!);
      case ActionType.investigate:
        return InvestigateAction(actor: actor, target: target!);
      case ActionType.heal:
        return HealAction(actor: actor, target: target!);
      case ActionType.poison:
        return PoisonAction(actor: actor, target: target!);
      default:
        throw Exception('Action type not implemented: $type');
    }
  }
}
```

## 6. 用户界面设计

### 6.1 控制台界面

```dart
class ConsoleUI {
  final DisplayManager displayManager;
  final InputHandler inputHandler;
  final GameLogger logger;

  Future<void> showGameStart(GameState state) async {
    displayManager.clear();
    displayManager.showBanner('狼人杀游戏开始');

    displayManager.showSection('玩家配置');
    for (final player in state.players) {
      displayManager.showPlayerInfo(player);
    }

    displayManager.showSection('游戏规则');
    displayManager.showRules();

    await _waitForUserInput('按回车键开始游戏...');
  }

  Future<void> showNightPhase(GameState state) async {
    displayManager.clear();
    displayManager.showBanner('第 ${state.dayNumber} 夜');

    displayManager.showSection('夜晚行动');
    displayManager.showMessage('天黑请闭眼...');

    // 显示各个角色的行动
    await _showNightActions(state);

    displayManager.showSection('行动结果');
    await _showNightResults(state);
  }

  Future<void> showDayPhase(GameState state) async {
    displayManager.clear();
    displayManager.showBanner('第 ${state.dayNumber} 天');

    displayManager.showSection('死亡信息');
    await _showDeathInfo(state);

    displayManager.showSection('玩家讨论');
    await _showDiscussion(state);

    displayManager.showSection('存活玩家');
    _showAlivePlayers(state);
  }

  Future<void> showVotingPhase(GameState state) async {
    displayManager.showSection('投票阶段');
    displayManager.showMessage('请玩家依次投票...');

    await _showVotingProcess(state);
    await _showVotingResults(state);
  }

  Future<void> showGameEnd(GameState state) async {
    displayManager.clear();
    displayManager.showBanner('游戏结束');

    displayManager.showSection('游戏结果');
    displayManager.showMessage('获胜阵营: ${state.winner}');

    displayManager.showSection('玩家身份揭晓');
    for (final player in state.players) {
      displayManager.showPlayerRole(player);
    }

    displayManager.showSection('游戏统计');
    await _showGameStats(state);
  }
}
```

### 6.2 输入处理器

```dart
class InputHandler {
  final Stream<String> input;
  final Queue<String> commandHistory;

  Future<UserCommand> waitForCommand() async {
    final input = await _readLine();
    commandHistory.add(input);

    return _parseCommand(input);
  }

  Future<bool> waitForConfirmation(String message) async {
    displayManager.showMessage('$message (Y/N)');
    final input = await _readLine();
    return input.toLowerCase() == 'y';
  }

  Future<int> waitForSelection(String message, int max) async {
    displayManager.showMessage('$message (1-$max)');
    final input = await _readLine();

    try {
      final selection = int.parse(input);
      if (selection >= 1 && selection <= max) {
        return selection - 1;
      }
    } catch (e) {
      // 忽略解析错误
    }

    return await waitForSelection(message, max);
  }

  UserCommand _parseCommand(String input) {
    final parts = input.split(' ');
    final command = parts[0].toLowerCase();
    final args = parts.skip(1).toList();

    switch (command) {
      case 'start':
        return UserCommand(type: CommandType.start, args: args);
      case 'pause':
        return UserCommand(type: CommandType.pause, args: args);
      case 'resume':
        return UserCommand(type: CommandType.resume, args: args);
      case 'quit':
        return UserCommand(type: CommandType.quit, args: args);
      case 'help':
        return UserCommand(type: CommandType.help, args: args);
      case 'status':
        return UserCommand(type: CommandType.status, args: args);
      case 'speed':
        return UserCommand(type: CommandType.speed, args: args);
      default:
        return UserCommand(type: CommandType.unknown, args: args);
    }
  }
}
```

### 6.3 显示管理器

```dart
class DisplayManager {
  final int consoleWidth;
  final int consoleHeight;
  final bool useColors;
  final AnimationService? animation;

  void clear() {
    print('\x1B[2J\x1B[0;0H');
  }

  void showBanner(String text) {
    final banner = _createBanner(text);
    print(_withColor(banner, ConsoleColor.cyan));
  }

  void showSection(String title) {
    print('\n${_withColor('=== $title ===', ConsoleColor.yellow)}');
  }

  void showMessage(String message) {
    print(message);
  }

  void showPlayerInfo(Player player) {
    final status = player.isAlive ? '存活' : '死亡';
    final info = '${player.name} ($status)';
    print(_withColor(info, player.isAlive ? ConsoleColor.green : ConsoleColor.red));
  }

  void showProgress(double progress, String message) {
    final bar = _createProgressBar(progress);
    print('$message: $bar');
  }

  void showList<T>(List<T> items, String Function(T) formatter) {
    for (int i = 0; i < items.length; i++) {
      print('${i + 1}. ${formatter(items[i])}');
    }
  }

  String _createBanner(String text) {
    final width = consoleWidth;
    final padding = (width - text.length - 4) ~/ 2;
    return '═' * width + '\n' +
           '║' + ' ' * padding + text + ' ' * padding + '║\n' +
           '═' * width;
  }

  String _createProgressBar(double progress) {
    final width = 30;
    final filled = (progress * width).round();
    return '[' + '█' * filled + '░' * (width - filled) + ']';
  }

  String _withColor(String text, ConsoleColor color) {
    if (!useColors) return text;
    return '${color.code}$text${ConsoleColor.reset.code}';
  }
}

enum ConsoleColor {
  black('\x1B[30m'),
  red('\x1B[31m'),
  green('\x1B[32m'),
  yellow('\x1B[33m'),
  blue('\x1B[34m'),
  magenta('\x1B[35m'),
  cyan('\x1B[36m'),
  white('\x1B[37m'),
  reset('\x1B[0m');

  final String code;
  const ConsoleColor(this.code);
}
```

## 7. 配置和工具类

### 7.1 游戏配置

```dart
class GameConfig {
  static GameConfig? _current;

  final int playerCount;
  final Map<RoleType, int> roleDistribution;
  final LLMConfig llmConfig;
  final GameRules rules;
  final UIConfig uiConfig;

  GameConfig({
    required this.playerCount,
    required this.roleDistribution,
    required this.llmConfig,
    required this.rules,
    required this.uiConfig,
  });

  static GameConfig get current {
    if (_current == null) {
      _current = _loadDefaultConfig();
    }
    return _current!;
  }

  static GameConfig _loadDefaultConfig() {
    return GameConfig(
      playerCount: 10,
      roleDistribution: {
        RoleType.werewolf: 2,
        RoleType.villager: 4,
        RoleType.god: 4,
      },
      llmConfig: LLMConfig.defaultConfig,
      rules: GameRules.standard,
      uiConfig: UIConfig.defaultConfig,
    );
  }

  static void loadFromFile(String path) {
    final json = File(path).readAsStringSync();
    final data = jsonDecode(json);
    _current = GameConfig.fromJson(data);
  }

  Map<String, dynamic> toJson() {
    return {
      'playerCount': playerCount,
      'roleDistribution': roleDistribution.map((k, v) => MapEntry(k.name, v)),
      'llmConfig': llmConfig.toJson(),
      'rules': rules.toJson(),
      'uiConfig': uiConfig.toJson(),
    };
  }

  factory GameConfig.fromJson(Map<String, dynamic> json) {
    return GameConfig(
      playerCount: json['playerCount'],
      roleDistribution: _parseRoleDistribution(json['roleDistribution']),
      llmConfig: LLMConfig.fromJson(json['llmConfig']),
      rules: GameRules.fromJson(json['rules']),
      uiConfig: UIConfig.fromJson(json['uiConfig']),
    );
  }
}

class LLMConfig {
  final String model;
  final String apiKey;
  final double temperature;
  final int maxTokens;
  final int timeoutSeconds;
  final int maxRetries;

  LLMConfig({
    required this.model,
    required this.apiKey,
    required this.temperature,
    required this.maxTokens,
    required this.timeoutSeconds,
    required this.maxRetries,
  });

  static LLMConfig get defaultConfig {
    return LLMConfig(
      model: 'gpt-3.5-turbo',
      apiKey: '',
      temperature: 0.7,
      maxTokens: 1000,
      timeoutSeconds: 30,
      maxRetries: 3,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'apiKey': apiKey,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'timeoutSeconds': timeoutSeconds,
      'maxRetries': maxRetries,
    };
  }
}
```

### 7.2 工具类

```dart
class RandomHelper {
  final Random _random = Random();

  int nextInt(int max) => _random.nextInt(max);
  double nextDouble() => _random.nextDouble();
  bool nextBool() => _random.nextBool();

  T weightedSelect<T>(List<T> items, List<double> weights) {
    if (items.length != weights.length) {
      throw Exception('Items and weights must have same length');
    }

    final totalWeight = weights.reduce((a, b) => a + b);
    final selection = _random.nextDouble() * totalWeight;

    double currentWeight = 0;
    for (int i = 0; i < items.length; i++) {
      currentWeight += weights[i];
      if (selection <= currentWeight) {
        return items[i];
      }
    }

    return items.last;
  }

  List<T> shuffle<T>(List<T> items) {
    final shuffled = List<T>.from(items);
    for (int i = shuffled.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final temp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = temp;
    }
    return shuffled;
  }
}

class GameLogger {
  final List<String> _logs = [];
  final LogLevel minLevel;
  final bool outputToConsole;

  GameLogger({
    this.minLevel = LogLevel.info,
    this.outputToConsole = true,
  });

  void debug(String message) {
    _log(LogLevel.debug, message);
  }

  void info(String message) {
    _log(LogLevel.info, message);
  }

  void warning(String message) {
    _log(LogLevel.warning, message);
  }

  void error(String message) {
    _log(LogLevel.error, message);
  }

  void _log(LogLevel level, String message) {
    if (level.index < minLevel.index) return;

    final timestamp = DateTime.now().toString();
    final logEntry = '[$timestamp] [${level.name.toUpperCase()}] $message';

    _logs.add(logEntry);

    if (outputToConsole) {
      print(logEntry);
    }
  }

  List<String> getLogs({LogLevel? level}) {
    if (level == null) return List.from(_logs);
    return _logs.where((log) => log.contains('[${level.name.toUpperCase()}]')).toList();
  }

  void saveToFile(String path) {
    final file = File(path);
    file.writeAsStringSync(_logs.join('\n'));
  }
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
}
```

## 8. 错误处理和恢复

### 8.1 错误类型定义

```dart
abstract class GameException implements Exception {
  final String message;
  final Exception? innerException;

  GameException(this.message, [this.innerException]);

  @override
  String toString() => message;
}

class InvalidActionException extends GameException {
  InvalidActionException(String message, [Exception? inner])
      : super(message, inner);
}

class GameStateException extends GameException {
  GameStateException(String message, [Exception? inner])
      : super(message, inner);
}

class LLMServiceException extends GameException {
  final int retryCount;

  LLMServiceException(String message, this.retryCount, [Exception? inner])
      : super(message, inner);
}

class ConfigurationException extends GameException {
  ConfigurationException(String message, [Exception? inner])
      : super(message, inner);
}
```

### 8.2 错误处理策略

```dart
class ErrorHandler {
  final GameLogger logger;
  final Map<Type, ExceptionHandler> handlers;

  ErrorHandler(this.logger) : handlers = {
    InvalidActionException: _handleInvalidAction,
    GameStateException: _handleGameStateError,
    LLMServiceException: _handleLLMError,
    ConfigurationException: _handleConfigurationError,
  };

  Future<T> handle<T>(Future<T> Function() operation, {
    String context = '',
    int maxRetries = 3,
  }) async {
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        logger.error('Error in $context (attempt $attempt/$maxRetries): $e');

        if (attempt >= maxRetries) {
          return await _handleFinalError(e, context);
        }

        await _handleRetry(e, attempt, maxRetries, context);
      }
    }

    throw GameException('Operation failed after $maxRetries attempts');
  }

  Future<void> _handleRetry(
    dynamic error,
    int attempt,
    int maxRetries,
    String context,
  ) async {
    if (error is LLMServiceException) {
      // LLM错误可能需要等待更长时间
      await Future.delayed(Duration(seconds: attempt * 2));
    } else {
      // 其他错误等待较短时间
      await Future.delayed(Duration(seconds: 1));
    }
  }

  Future<T> _handleFinalError<T>(dynamic error, String context) async {
    final handler = handlers[error.runtimeType];
    if (handler != null) {
      return await handler(error, context);
    }

    // 默认错误处理
    logger.error('Unhandled error in $context: $error');
    throw error;
  }

  static Future<T> _handleInvalidAction<T>(dynamic error, String context) async {
    logger.warning('Invalid action in $context: ${error.message}');
    // 返回默认值或抛出特定异常
    throw error;
  }

  static Future<T> _handleLLMError<T>(dynamic error, String context) async {
    logger.warning('LLM service error in $context: ${error.message}');
    // 使用备用策略或默认响应
    throw error;
  }

  static Future<T> _handleGameStateError<T>(dynamic error, String context) async {
    logger.error('Game state error in $context: ${error.message}');
    // 尝试恢复游戏状态
    throw error;
  }
}

typedef ExceptionHandler = Future<T> Function<T>(dynamic error, String context);
```

## 9. 性能优化

### 9.1 缓存系统

```dart
class ResponseCache {
  final Map<String, CacheEntry> _cache = {};
  final Duration maxAge;
  final int maxSize;

  ResponseCache({
    this.maxAge = const Duration(minutes:30),
    this.maxSize = 1000,
  });

  String? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (DateTime.now().difference(entry.timestamp) > maxAge) {
      _cache.remove(key);
      return null;
    }

    return entry.response;
  }

  void put(String key, String response) {
    if (_cache.length >= maxSize) {
      _evictOldest();
    }

    _cache[key] = CacheEntry(
      response: response,
      timestamp: DateTime.now(),
    );
  }

  void _evictOldest() {
    if (_cache.isEmpty) return;

    final oldest = _cache.entries.reduce((a, b) =>
      a.value.timestamp.isBefore(b.value.timestamp) ? a : b
    );

    _cache.remove(oldest.key);
  }

  void clear() {
    _cache.clear();
  }

  int get size => _cache.length;
}

class CacheEntry {
  final String response;
  final DateTime timestamp;

  CacheEntry({
    required this.response,
    required this.timestamp,
  });
}
```

### 9.2 批处理和并发

```dart
class ActionProcessor {
  final int maxConcurrentActions;
  final Queue<GameAction> _actionQueue = Queue();
  final Set<Future> _activeActions = {};

  ActionProcessor({this.maxConcurrentActions = 3});

  Future<void> addAction(GameAction action) {
    _actionQueue.add(action);
    _processQueue();
  }

  void _processQueue() {
    while (_actionQueue.isNotEmpty && _activeActions.length < maxConcurrentActions) {
      final action = _actionQueue.removeFirst();
      final future = _executeAction(action);

      _activeActions.add(future);

      future.then((_) {
        _activeActions.remove(future);
        _processQueue();
      });
    }
  }

  Future<void> _executeAction(GameAction action) async {
    try {
      await action.execute();
    } catch (e) {
      // 处理动作执行错误
    }
  }
}
```

## 10. 测试策略

### 10.1 单元测试

```dart
class GameEngineTest {
  late GameEngine engine;
  late MockLLMService mockLLM;
  late MockDisplayManager mockDisplay;

  setUp() {
    mockLLM = MockLLMService();
    mockDisplay = MockDisplayManager();
    engine = GameEngine(
      llmService: mockLLM,
      displayManager: mockDisplay,
    );
  }

  test('Game starts correctly', () async {
    // Arrange
    final config = GameConfig.testConfig;

    // Act
    await engine.startGame(config);

    // Assert
    expect(engine.state.status, GameStatus.playing);
    expect(engine.state.players.length, config.playerCount);
  });

  test('Night phase processes werewolf actions', () async {
    // Arrange
    await engine.startGame(GameConfig.testConfig);
    engine.state.currentPhase = GamePhase.night;

    // Act
    await engine.processNightPhase();

    // Assert
    verify(mockLLM.generateAction(any, any, any)).called(equals(2));
  });
}

class MockLLMService extends Mock implements LLMService {
  @override
  Future<LLMResponse> generateAction({
    required Player player,
    required GameState state,
    required RolePrompt rolePrompt,
  }) async {
    // 返回预设的测试响应
    return LLMResponse.test();
  }
}
```

### 10.2 集成测试

```dart
class IntegrationTest {
  test('Full game flow works correctly', () async {
    // Arrange
    final engine = GameEngine(
      llmService: TestLLMService(),
      displayManager: TestDisplayManager(),
    );

    // Act
    await engine.startGame(GameConfig.testConfig);

    // 运行完整游戏
    while (!engine.state.isGameOver) {
      await engine.processNextPhase();
    }

    // Assert
    expect(engine.state.isGameOver, isTrue);
    expect(engine.state.winner, isNotNull);
  });
}
```

## 11. 部署和发布

### 11.1 构建配置

```yaml
# pubspec.yaml
name: werewolf_arena
version: 1.0.0
description: A Werewolf game with LLM players
environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  http: ^1.1.0
  json_annotation: ^4.8.1
  logging: ^1.2.0
  args: ^2.4.2

dev_dependencies:
  test: ^1.24.0
  mocktail: ^0.3.0
  build_runner: ^2.4.6
  json_serializable: ^6.7.1

executables:
  werewolf_arena:
```

### 11.2 命令行界面

```dart
class CLI {
  final GameEngine engine;
  final ConsoleUI ui;

  CLI(this.engine, this.ui);

  static Future<void> main(List<String> args) async {
    final parser = ArgParser();
    parser.addOption('config', abbr: 'c', help: 'Configuration file path');
    parser.addOption('players', abbr: 'p', help: 'Number of players');
    parser.addFlag('help', abbr: 'h', help: 'Show help');

    try {
      final results = parser.parse(args);

      if (results['help']) {
        _showHelp(parser);
        return;
      }

      final config = await _loadConfig(results);
      final engine = GameEngine(config: config);
      final ui = ConsoleUI();
      final cli = CLI(engine, ui);

      await cli.run();
    } catch (e) {
      print('Error: $e');
      exit(1);
    }
  }

  Future<void> run() async {
    // 显示欢迎界面
    await ui.showWelcome();

    // 等待用户开始
    await ui.waitForStart();

    // 开始游戏
    await engine.startGame();

    // 主游戏循环
    while (!engine.state.isGameOver) {
      await ui.showGameState(engine.state);
      await _processUserInput();

      if (engine.state.status == GameStatus.playing) {
        await engine.processNextPhase();
      }
    }

    // 显示游戏结果
    await ui.showGameEnd(engine.state);
  }
}
```

这个详细设计文档提供了完整的技术实现方案，包括：

1. 系统架构和组件设计
2. 核心数据结构定义
3. 游戏流程和状态管理
4. 角色系统和AI行为
5. LLM集成和提示词设计
6. 用户界面和交互设计
7. 配置管理和工具类
8. 错误处理和性能优化
9. 测试策略和部署方案

文档中的代码示例可以直接用于实现，为开发团队提供了清晰的指导。