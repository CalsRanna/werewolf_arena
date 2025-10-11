# Werewolf Arena v2.0.0 迁移指南

## 文档信息
- **版本**: 2.0.0
- **日期**: 2025-10-11
- **目标架构**: 四组件架构 (GameConfig, GameScenario, GamePlayer, GameObserver)

## 概述

Werewolf Arena v2.0.0 进行了重大架构升级，从复杂的 GameParameters 接口重构为简洁的四组件架构。本指南将帮助开发者从 v1.x 迁移到 v2.0.0。

## 核心破坏性变更

### 1. 游戏引擎创建方式

**v1.x (旧版本)**:
```dart
// 复杂的参数系统初始化
final parameters = FlutterGameParameters.instance;
await parameters.initialize();
parameters.setCurrentScenario('9_players');

// 创建游戏引擎
final engine = GameEngine(parameters: parameters);

// 外部创建玩家
final players = createPlayersForScenario(parameters.scenario!, parameters.config);
engine.setPlayers(players);
```

**v2.0.0 (新版本)**:
```dart
// 1. 使用GameAssembler创建游戏（推荐）
final gameEngine = await GameAssembler.assembleGame(
  scenarioId: '9_players',               // 9人局
  // configPath: 'path/to/config.yaml', // 可选：自定义配置
  // observer: customObserver,           // 可选：自定义观察者
);

// 2. 启动游戏
await gameEngine.initializeGame();

// 3. 执行游戏步骤
while (!gameEngine.isGameEnded) {
  await gameEngine.executeGameStep();
}
```

### 2. 配置系统简化

**v1.x (旧版本)**:
```dart
class AppConfig {
  final LLMConfig defaultLLM;
  final Map<int, LLMConfig> playerModels;
  final LoggingConfig logging;
  final TimeoutConfig timeouts;
  final GameplayConfig gameplay;
  // ... 大量配置字段
}
```

**v2.0.0 (新版本)**:
```dart
class GameConfig {
  final List<PlayerIntelligence> playerIntelligences;
  final int maxRetries;
  
  GameConfig({
    required this.playerIntelligences,
    required this.maxRetries,
  });
}

class PlayerIntelligence {
  final String baseUrl;
  final String apiKey;
  final String modelId;
  
  PlayerIntelligence({
    required this.baseUrl,
    required this.apiKey,
    required this.modelId,
  });
}
```

### 3. 玩家架构重构

**v1.x (旧版本)**:
```dart
class Player {
  final String id;
  final String name;
  final PlayerType type; // 枚举：ai, human
  // ...
}

// 使用枚举进行类型判断
if (player.type == PlayerType.ai) {
  // AI 玩家逻辑
}
```

**v2.0.0 (新版本)**:
```dart
// 抽象基类
abstract class GamePlayer {
  String get id;
  String get name;
  PlayerDriver get driver; // 每个玩家有自己的Driver
  // ...
}

// 具体实现
class AIPlayer extends GamePlayer {
  @override
  final PlayerDriver driver; // AIPlayerDriver实例
  // ...
}

class HumanPlayer extends GamePlayer {
  @override
  final PlayerDriver driver; // HumanPlayerDriver实例
  // ...
}

// 使用面向对象方式进行类型判断
if (player is AIPlayer) {
  // AI 玩家逻辑
}
```

### 4. 角色系统升级

**v1.x (旧版本)**:
```dart
abstract class Role {
  String get name;
  RoleType get type;
  bool get isWerewolf;
  // ...
}

class WerewolfRole extends Role {
  // 角色逻辑分散在各处
}
```

**v2.0.0 (新版本)**:
```dart
abstract class GameRole {
  String get roleId;
  String get name;
  String get rolePrompt;        // 角色身份提示词
  List<GameSkill> get skills;   // 角色拥有的技能列表
  
  List<GameSkill> getAvailableSkills(GamePhase phase);
}

class WerewolfGameRole implements GameRole {
  @override
  List<GameSkill> get skills => [
    WerewolfKillSkill(),    // 狼人击杀技能
    WerewolfDiscussSkill(), // 狼人讨论技能
  ];
  
  @override
  String get rolePrompt => '''
你是一个狼人，在狼人杀游戏中属于狼人阵营。
你的目标是与队友合作，消灭所有好人。
''';
}
```

### 5. 技能系统统一

**v1.x (旧版本)**:
```dart
// 分散的Action系统
abstract class ActionProcessor {
  Future<void> processAction(GameState state, PlayerAction action);
}

class WerewolfActionProcessor extends ActionProcessor {
  // 狼人行动处理
}
```

**v2.0.0 (新版本)**:
```dart
// 统一的技能系统
abstract class GameSkill {
  String get skillId;
  String get name;
  String get prompt;              // 技能专用提示词
  int get priority;               // 执行优先级
  
  bool canCast(GamePlayer player, GameState state);
  Future<SkillResult> cast(GamePlayer player, GameState state);
}

class WerewolfKillSkill extends GameSkill {
  @override
  String get prompt => '''
现在是夜晚阶段，你需要和狼人队友讨论并选择击杀目标。
请考虑以下因素：
1. 谁最可能是神职？
2. 谁对你的威胁最大？
3. 如何隐藏身份？
''';
  
  @override
  Future<SkillResult> cast(GamePlayer player, GameState state) async {
    // 技能执行逻辑
  }
}
```

### 6. 游戏阶段简化

**v1.x (旧版本)**:
```dart
enum GamePhase {
  night,    // 夜晚阶段
  day,      // 白天阶段
  voting,   // 投票阶段
}
```

**v2.0.0 (新版本)**:
```dart
enum GamePhase {
  night,    // 夜晚阶段（狼人击杀、守卫保护等）
  day,      // 白天阶段（发言讨论 + 投票出局）
}
```

### 7. 状态管理简化

**v1.x (旧版本)**:
```dart
class GameState {
  GameStatus status;           // 游戏状态
  NightActionState nightActions;
  VotingState votingState;
  // ...
}
```

**v2.0.0 (新版本)**:
```dart
class GameState {
  // 移除了 status 字段，由 GameEngine 管理
  // 移除了复杂的子状态类
  
  // 直接管理技能效果
  Map<String, dynamic> get skillEffects;
  void setSkillEffect(String key, dynamic value);
  dynamic getSkillEffect(String key);
}

class GameEngine {
  GameEngineStatus _status = GameEngineStatus.waiting; // 引擎自己管理状态
}
```

## 详细迁移步骤

### 步骤1: 更新游戏创建代码

将现有的游戏创建代码替换为 GameAssembler 模式：

```dart
// 替换前
final parameters = FlutterGameParameters.instance;
await parameters.initialize();
final engine = GameEngine(parameters: parameters);

// 替换后
final engine = await GameAssembler.assembleGame(
  scenarioId: '9_players',
  observer: StreamGameObserver(), // 可选
);
```

### 步骤2: 更新配置管理

```dart
// 替换前
final config = AppConfig(
  defaultLLM: LLMConfig(...),
  playerModels: {...},
  // 大量配置
);

// 替换后
final config = GameConfig(
  playerIntelligences: [
    PlayerIntelligence(
      baseUrl: 'https://api.openai.com/v1',
      apiKey: 'your-api-key',
      modelId: 'gpt-4',
    ),
    // 为每个玩家配置
  ],
  maxRetries: 3,
);
```

### 步骤3: 更新玩家类型检查

```dart
// 替换前
if (player.type == PlayerType.ai) {
  final aiPlayer = player as AIPlayer;
  // AI 逻辑
}

// 替换后
if (player is AIPlayer) {
  // AI 逻辑，直接使用 player
}
```

### 步骤4: 更新角色和技能系统

```dart
// 替换前
class MyRole extends Role {
  @override
  Future<void> performNightAction(GameState state) async {
    // 夜晚行动逻辑
  }
}

// 替换后
class MyGameRole implements GameRole {
  @override
  List<GameSkill> get skills => [
    MyNightSkill(),
    MySpeechSkill(),
  ];
  
  @override
  String get rolePrompt => '你的角色身份描述...';
}

class MyNightSkill extends GameSkill {
  @override
  String get prompt => '夜晚行动的具体提示词...';
  
  @override
  Future<SkillResult> cast(GamePlayer player, GameState state) async {
    // 技能执行逻辑
  }
}
```

### 步骤5: 更新游戏流程控制

```dart
// 替换前
while (!gameState.isGameEnded) {
  switch (gameState.currentPhase) {
    case GamePhase.night:
      await processNightPhase();
      break;
    case GamePhase.day:
      await processDayPhase();
      break;
    case GamePhase.voting:
      await processVotingPhase();
      break;
  }
}

// 替换后
await gameEngine.initializeGame();
while (!gameEngine.isGameEnded) {
  await gameEngine.executeGameStep(); // 引擎内部处理所有阶段逻辑
}
```

## 性能改进

新架构带来的性能提升：

- **初始化性能**: 9人局平均427μs，12人局平均232μs
- **技能系统执行**: 平均2.62μs，TPS达38万+
- **事件系统处理**: 事件添加平均0.69μs，查询平均219μs
- **游戏循环性能**: 平均游戏时间0.4ms，吞吐量1666 games/sec

## 常见问题和解决方案

### Q1: 如何获取玩家的可见事件？

**v2.0.0**:
```dart
final visibleEvents = gameState.getEventsForGamePlayer(player);
```

### Q2: 如何创建自定义角色？

**v2.0.0**:
```dart
class CustomGameRole implements GameRole {
  @override
  String get roleId => 'custom_role';
  
  @override
  List<GameSkill> get skills => [
    CustomSkill(),
  ];
  
  @override
  String get rolePrompt => '自定义角色的身份描述...';
}
```

### Q3: 如何处理人类玩家输入？

**v2.0.0**:
```dart
class HumanPlayer extends GamePlayer {
  void submitSkillResult(SkillResult result) {
    _actionController.add(result);
  }
  
  @override
  Future<SkillResult> executeSkill(GameSkill skill, GameState state) async {
    // 等待人类用户通过UI输入
    return await _actionController.stream.firstWhere(
      (result) => result.caster == this,
    );
  }
}
```

### Q4: 如何自定义游戏观察者？

**v2.0.0**:
```dart
class CustomGameObserver implements GameObserver {
  @override
  void onStateChange(GameState state) {
    // 处理状态变化
  }
  
  @override
  void onGameEvent(GameEvent event) {
    // 处理游戏事件
  }
}

final engine = await GameAssembler.assembleGame(
  scenarioId: '9_players',
  observer: CustomGameObserver(),
);
```

## 兼容性说明

### 不再支持的特性

1. **GameParameters 接口**: 完全移除，使用四组件架构替代
2. **PlayerType 枚举**: 使用面向对象的继承关系替代
3. **三阶段游戏流程**: 简化为两阶段（Night/Day）
4. **复杂的状态管理类**: NightActionState、VotingState等被移除

### 保持兼容的特性

1. **事件系统**: 基本保持兼容，事件类型和可见性规则不变
2. **GameObserver 接口**: 保持兼容，可以继续使用现有观察者
3. **配置文件格式**: 基本保持兼容，只是简化了配置项

## 测试更新

更新现有测试以适应新架构：

```dart
// v2.0.0 测试示例
test('9人局游戏测试', () async {
  final gameEngine = await GameAssembler.assembleGame(
    scenarioId: '9_players',
  );
  
  await gameEngine.initializeGame();
  
  expect(gameEngine.players.length, equals(9));
  expect(gameEngine.currentState?.currentPhase, equals(GamePhase.night));
  expect(gameEngine.status, equals(GameEngineStatus.playing));
});
```

## 总结

v2.0.0 架构升级大幅简化了游戏引擎的使用方式，提供了更好的性能和可维护性。主要迁移要点：

1. 使用 `GameAssembler.assembleGame()` 替代复杂的参数初始化
2. 用继承关系替代枚举进行类型判断
3. 用统一的技能系统替代分散的Action处理
4. 简化的两阶段游戏流程
5. 每个玩家拥有独立的PlayerDriver

通过遵循本指南，你可以顺利将现有代码迁移到新架构，并享受更好的开发体验和性能表现。