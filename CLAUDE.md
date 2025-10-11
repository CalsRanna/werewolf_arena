# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 重要工作规则 (最高优先级)

**1. 语言要求**：永远使用中文回答所有问题和进行交流。

**2. 第三方包使用规范**：在使用任何 Dart 第三方包之前，必须先通过 context7 这个 MCP 工具获取最新的文档知识和 API 使用模式。不依赖记忆中的过时信息。

**3. 游戏执行限制**：绝对不要尝试执行 `dart bin/werewolf_arena.dart` 或 `dart run bin/console.dart` 来测试程序运行情况。完整游戏执行时间很长（6-10分钟），且会消耗大量 token。只使用静态分析、编译检查和单元测试来验证代码。

**4. 导入路径规范**：永远使用完整的导入路径而不使用相对路径。例如使用 `import 'package:werewolf_arena/core/state/game_state.dart';` 而不是 `import '../state/game_state.dart';`。

**5. 代码生成要求**：修改数据模型或路由后，必须运行 `dart run build_runner build` 以重新生成相关代码。

## Project Overview

Werewolf Arena 是一个 AI 驱动的狼人杀游戏，支持两种运行模式：
- **Flutter GUI 模式**：通过 `flutter run` 启动的图形界面应用，支持多平台（macOS、Windows、Linux）
- **命令行模式**：通过 `dart run bin/console.dart` 启动的纯控制台版本

游戏使用 LLM（大语言模型）为 AI 玩家提供智能决策能力，支持经典狼人杀玩法，包括狼人、平民、预言家、女巫、猎人、守卫等多种角色。

### 新架构特点（v2.0.0）

项目于2025年10月完成了重大架构升级，实现了真正的职责分离和自洽运行：

- **简化的配置系统**：从复杂的GameParameters接口简化为4个独立组件（GameConfig、GameScenario、GamePlayer、GameObserver）
- **多态玩家架构**：GamePlayer抽象基类 + AIPlayer和HumanPlayer实现，每个玩家拥有独立的PlayerDriver
- **统一技能系统**：基于GameSkill抽象类的统一技能架构，消除概念碎片化
- **两阶段游戏流程**：简化为Night（夜晚）和Day（白天+投票）两个阶段
- **自洽游戏引擎**：GameEngine获得必要信息后能够自洽运转，不依赖外部参数管理

## Development Commands

### Running the Game
```bash
# Flutter GUI 模式（推荐用于开发和调试）
flutter run                    # 默认启动图形界面
flutter run -d macos          # 指定 macOS 平台
flutter run -d windows        # 指定 Windows 平台
flutter run -d linux          # 指定 Linux 平台

# 命令行模式（不要用于测试！）
# 注意：不要执行此命令进行测试，游戏运行时间长达 6-10 分钟
dart run bin/console.dart              # 使用默认配置
dart run bin/console.dart --config config/custom_config.yaml
dart run bin/console.dart --players 9
dart run bin/console.dart --debug
```

### Development Tasks
```bash
# 依赖管理
dart pub get          # 安装 Dart 依赖
flutter pub get       # 安装 Flutter 依赖（推荐）

# 代码质量检查
dart analyze          # 静态代码分析
flutter analyze       # Flutter 专用分析

# 测试
dart test             # 运行所有测试
dart test test/game_config_test.dart          # 运行单个测试文件
dart test --coverage=coverage                 # 运行覆盖率测试
dart test test/performance_test.dart          # 运行性能测试
dart test test/memory_test.dart               # 运行内存测试

# 代码生成（修改路由或数据模型后必须执行）
dart run build_runner build                  # 生成代码
dart run build_runner build --delete-conflicting-outputs  # 强制重新生成
dart run build_runner watch                  # 监听文件变化自动生成
```

## Architecture

### 新架构概览（v2.0.0）

```
新架构四大核心组件：
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   GameConfig    │  │  GameScenario   │  │   GamePlayer    │  │  GameObserver   │
│                 │  │                 │  │                 │  │                 │
│ • PlayerIntell  │  │ • 角色配置      │  │ • AIPlayer      │  │ • UI层通信      │
│ • LLM配置       │  │ • 游戏规则      │  │ • HumanPlayer   │  │ • 事件分发      │
│ • 重试次数      │  │ • 胜利条件      │  │ • PlayerDriver  │  │ • 状态同步      │
└─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────┘
         │                    │                    │                    │
         └────────────────────┼────────────────────┼────────────────────┘
                              │                    │
                    ┌─────────▼────────────────────▼─────────┐
                    │           GameEngine                   │
                    │   • 自洽运行，无外部依赖              │
                    │   • 处理器模式管理游戏流程             │
                    │   • Observer模式与UI解耦               │
                    └────────────────────────────────────────┘
```

### 目录结构

```
lib/
├── core/                    # 核心游戏逻辑（DDD架构，与 UI 无关）
│   ├── domain/              # 领域模型层
│   │   ├── entities/        # 实体
│   │   │   ├── game_player.dart       # 游戏玩家抽象基类（重构）
│   │   │   ├── ai_player.dart         # AI玩家实体，集成LLM决策
│   │   │   ├── human_player.dart      # 人类玩家实体，等待用户输入
│   │   │   ├── game_role.dart         # 游戏角色抽象基类（重构）
│   │   │   └── role_implementations.dart # 所有角色实现（统一文件）
│   │   ├── value_objects/   # 值对象
│   │   │   ├── game_config.dart       # 游戏配置类（新架构核心）
│   │   │   ├── config_loader.dart     # 配置加载器
│   │   │   ├── game_phase.dart        # 游戏阶段枚举
│   │   │   ├── game_engine_status.dart# 游戏引擎状态（重命名）
│   │   │   ├── death_cause.dart       # 死亡原因枚举
│   │   │   ├── event_visibility.dart  # 事件可见性枚举
│   │   │   ├── game_event_type.dart   # 游戏事件类型枚举
│   │   │   ├── vote_type.dart         # 投票类型枚举
│   │   │   ├── speech_type.dart       # 发言类型枚举
│   │   │   └── victory_result.dart    # 胜利结果（替代GameEndResult）
│   │   └── enums/           # 其他枚举类型
│   │       ├── role_type.dart         # 角色类型枚举
│   │       └── role_alignment.dart    # 角色阵营枚举
│   ├── drivers/             # 玩家驱动器（新架构）
│   │   ├── player_driver.dart         # PlayerDriver抽象接口
│   │   ├── ai_player_driver.dart      # AI玩家驱动器，集成LLM
│   │   └── human_player_driver.dart   # 人类玩家驱动器，等待输入
│   ├── skills/              # 技能系统（重构）
│   │   ├── game_skill.dart            # GameSkill抽象基类
│   │   ├── skill_result.dart          # 技能结果类
│   │   ├── skill_processor.dart       # 技能处理器，处理冲突
│   │   ├── base_skills.dart           # 基础技能实现
│   │   ├── night_skills.dart          # 夜晚技能实现
│   │   └── day_skills.dart            # 白天技能实现
│   ├── events/              # 事件系统(CQRS/Event Sourcing)
│   │   ├── base/            # 事件基类
│   │   │   └── game_event.dart        # 事件基类和GameEventType
│   │   ├── player_events.dart         # 玩家相关事件
│   │   ├── skill_events.dart          # 技能相关事件
│   │   ├── phase_events.dart          # 阶段相关事件
│   │   └── system_events.dart         # 系统事件
│   ├── state/               # 状态管理
│   │   └── game_state.dart            # 游戏状态容器（简化）
│   ├── engine/              # 游戏引擎核心
│   │   ├── game_engine_new.dart       # 新游戏引擎（4参数构造）
│   │   ├── game_assembler.dart        # 游戏组装器（外部逻辑）
│   │   ├── game_observer.dart         # 游戏观察者接口
│   │   ├── utils/
│   │   │   └── game_random.dart       # 游戏随机数工具
│   │   └── processors/              # 处理器模式
│   │       ├── phase_processor.dart      # 阶段处理器接口
│   │       ├── night_phase_processor.dart# 夜晚阶段处理器
│   │       └── day_phase_processor.dart  # 白天阶段处理器
│   ├── scenarios/           # 游戏场景
│   │   ├── game_scenario.dart         # 场景抽象接口（简化）
│   │   ├── scenario_9_players.dart    # 9人局场景
│   │   └── scenario_12_players.dart   # 12人局场景
│   └── rules/               # 游戏规则引擎
│       └── victory_conditions.dart    # 胜利条件判定（独立）
├── services/                # 服务层
│   ├── game_service.dart              # 游戏服务（Flutter包装层）
│   ├── config/              # 配置管理
│   │   └── config.dart                # 配置数据结构（简化）
│   ├── llm/                 # LLM 集成
│   │   ├── llm_service.dart           # LLM 服务
│   │   └── json_cleaner.dart          # JSON 清理工具
│   ├── logging/             # 日志系统
│   │   ├── logger.dart                # 通用日志
│   │   └── player_logger.dart         # 玩家日志
│   └── stream_game_observer.dart      # Stream事件流观察者
├── page/                    # Flutter 页面（MVVM 架构）
│   ├── bootstrap/           # 启动页
│   ├── home/                # 主页
│   ├── game/                # 游戏页面
│   └── settings/            # 设置页面（包含 LLM 配置）
├── widget/                  # Flutter 组件
│   └── console/             # 控制台相关组件
│       ├── console_adapter.dart       # 控制台适配器
│       └── console_callback_handler.dart # 控制台回调处理
├── router/                  # 路由配置（auto_route）
│   ├── router.dart                    # 路由定义
│   └── router.gr.dart                 # 生成的路由代码
├── di.dart                  # 依赖注入配置（GetIt）
├── main.dart                # Flutter 应用入口
└── util/                    # 工具类
    └── responsive.dart                # 响应式布局工具

bin/
└── main.dart                # 命令行模式入口（重构）

config/
└── default_config.yaml      # 默认游戏配置

test/
├── game_config_test.dart            # 配置系统测试
├── game_player_test.dart            # 玩家系统测试
├── game_scenario_test.dart          # 场景系统测试
├── skill_system_test.dart           # 技能系统测试
├── integration_test.dart            # 集成测试
├── performance_test.dart            # 性能测试
└── memory_test.dart                 # 内存测试
```

### 核心组件详解

#### 1. GameConfig - 简化的配置系统
**职责**：提供游戏引擎运行所必需的技术参数
```dart
class GameConfig {
  final List<PlayerIntelligence> playerIntelligences;  // 玩家智能配置列表
  final int maxRetries;                                 // 最大重试次数
  
  // 获取指定玩家的智能配置
  PlayerIntelligence? getPlayerIntelligence(int playerIndex);
  PlayerIntelligence? get defaultIntelligence;
}

class PlayerIntelligence {
  final String baseUrl;     // API基础URL
  final String apiKey;      // API密钥  
  final String modelId;     // 模型ID
}
```

#### 2. GameScenario - 游戏场景定义
**职责**：定义游戏规则、角色配置和胜利条件
```dart
abstract class GameScenario {
  String get id;                              // 场景唯一标识
  String get name;                            // 场景名称
  String get description;                     // 场景描述
  int get playerCount;                        // 玩家数量
  String get rule;                            // 游戏规则说明（用户可见）
  
  List<RoleType> getExpandedGameRoles();      // 获取角色列表
  GameRole createGameRole(RoleType roleType); // 创建角色实例
}
```

#### 3. GamePlayer - 多态玩家架构
**职责**：统一的玩家抽象，支持AI和人类玩家
```dart
abstract class GamePlayer {
  String get id;
  String get name; 
  int get index;
  GameRole get role;
  PlayerDriver get driver;                    // 每个玩家有独立的驱动器
  
  Future<SkillResult> executeSkill(GameSkill skill, GameState state);
  
  // 静态工厂方法
  static AIPlayer ai({required String id, required String name, required GameRole role});
  static HumanPlayer human({required String id, required String name, required GameRole role});
}
```

#### 4. GameEngine - 自洽游戏引擎
**职责**：纯粹的游戏逻辑执行器，获得必要信息后能够自洽运转
```dart
class GameEngine {
  GameEngine({
    required GameConfig config,          // 只需要4个参数
    required GameScenario scenario,
    required List<GamePlayer> players,
    GameObserver? observer,
  });
  
  Future<void> initializeGame();         // 初始化游戏
  Future<bool> executeGameStep();        // 执行游戏步骤，返回是否继续
  
  GameEngineStatus get status;           // 引擎状态
  GameState? get currentState;           // 当前游戏状态
}
```

#### 5. GameAssembler - 游戏组装器
**职责**：负责外部逻辑（配置加载、场景选择、玩家创建）
```dart
class GameAssembler {
  static Future<GameEngine> assembleGame({
    String? configPath,                   // 配置文件路径（可选）
    String? scenarioId,                   // 场景ID（可选）
    int? playerCount,                     // 玩家数量（可选）
    GameObserver? observer,               // 游戏观察者（可选）
  });
  
  // 实用方法
  static List<GameScenario> getAvailableScenarios();
  static bool validateConfig(GameConfig config);
}
```

### 关键架构模式

#### 1. 处理器模式
**设计原理**：将复杂的游戏逻辑分解为独立的处理器组件
```dart
abstract class PhaseProcessor {
  GamePhase get supportedPhase;
  Future<void> process(GameState state);
}

class NightPhaseProcessor implements PhaseProcessor {
  // 基于技能系统重构，统一处理所有夜晚行动
  Future<void> process(GameState state) async {
    // 1. 收集可用技能
    // 2. 按优先级排序执行
    // 3. 技能冲突解析
    // 4. 生成夜晚结果事件
  }
}
```

#### 2. 技能系统统一架构
**设计原理**：基于GameSkill抽象类的统一技能架构，消除概念碎片化
```dart
abstract class GameSkill {
  String get skillId;
  String get name;
  String get description;
  int get priority;                       // 技能执行优先级
  String get prompt;                      // 技能提示词
  
  bool canCast(GamePlayer player, GameState state);
  Future<SkillResult> cast(GamePlayer player, GameState state);
}

class SkillProcessor {
  // 处理技能结果和冲突（如保护vs击杀）
  Future<void> process(List<SkillResult> results, GameState state);
}
```

#### 3. PlayerDriver模式
**设计原理**：每个玩家拥有独立的驱动器，统一AI响应接口
```dart
abstract class PlayerDriver {
  Future<dynamic> generateSkillResponse(
    GamePlayer player,
    GameSkill skill,
    GameState state,
  );
}

class AIPlayerDriver extends PlayerDriver {
  // 集成OpenAIService用于AI决策
  // 使用PlayerIntelligence配置LLM连接
}

class HumanPlayerDriver extends PlayerDriver {
  // 等待人类输入的逻辑框架
  // 支持超时处理和状态查询
}
```

#### 4. 事件驱动架构
**设计原理**：所有游戏行为通过事件表示，事件有可见性规则
```dart
abstract class GameEvent {
  String get eventId;
  GameEventType get type;
  GamePlayer? get initiator;
  GamePlayer? get target;
  EventVisibility get visibility;
  DateTime get timestamp;
  
  bool isVisibleTo(GamePlayer player);    // 可见性规则
  Map<String, dynamic> toJson();
}
```

#### 5. Observer模式解耦
**设计原理**：GameEngine通过Observer接口与外部系统通信
```dart
abstract class GameObserver {
  void onGameStart(GameState state);
  void onGameEnd(GameState state, String winner);
  void onPhaseChange(GameState state, GamePhase oldPhase, GamePhase newPhase);
  void onGamePlayerAction(GameState state, GamePlayer player, dynamic action);
}
```

### 两阶段游戏流程

新架构将游戏简化为两个核心阶段：

#### Night阶段：夜晚行动
- 狼人击杀（优先级最高）
- 守卫保护
- 预言家查验
- 女巫用药
- **统一通过技能系统处理，支持冲突解析**

#### Day阶段：白天讨论 + 投票
- 夜晚结果公布
- 玩家依次发言讨论
- 投票出局（原投票阶段合并）
- 遗言和猎人技能
- **一个阶段完成所有白天活动**

### API使用指南

#### 创建游戏的标准方式

```dart
// 1. 使用GameAssembler创建游戏（推荐）
final gameEngine = await GameAssembler.assembleGame(
  scenarioId: '9_players',               // 9人局
  // configPath: 'path/to/config.yaml', // 可选：自定义配置
  // observer: customObserver,           // 可选：自定义观察者
);

// 2. 初始化并运行游戏
await gameEngine.initializeGame();

// 3. 执行游戏循环
while (await gameEngine.executeGameStep()) {
  // 游戏继续运行
  if (gameEngine.currentState!.checkGameEnd()) {
    break;
  }
}
```

#### 创建自定义玩家

```dart
// 创建AI玩家（使用工厂方法）
final aiPlayer = GamePlayer.ai(
  id: 'ai_1',
  name: '1号玩家',
  role: werewolfRole,
);

// 创建人类玩家
final humanPlayer = GamePlayer.human(
  id: 'human_1', 
  name: '1号玩家(人类)',
  role: villagerRole,
);

// 创建混合模式游戏
final players = await GameAssembler.createMixedPlayers(
  scenario,
  config,
  [1, 3, 5], // 1、3、5号位为人类玩家
);
```

#### 监听游戏事件

```dart
class MyGameObserver extends GameObserver {
  @override
  void onPhaseChange(GameState state, GamePhase oldPhase, GamePhase newPhase) {
    print('阶段切换：$oldPhase -> $newPhase');
  }
  
  @override
  void onGamePlayerAction(GameState state, GamePlayer player, action) {
    print('${player.name} 执行了行动');
  }
}

// 使用自定义观察者
final gameEngine = await GameAssembler.assembleGame(
  scenarioId: '9_players',
  observer: MyGameObserver(),
);
```

#### 自定义游戏场景

```dart
class CustomScenario implements GameScenario {
  @override
  String get id => 'custom_10_players';
  
  @override 
  String get name => '自定义10人局';
  
  @override
  int get playerCount => 10;
  
  @override
  String get rule => '''
  自定义10人局规则：
  - 3狼人 + 1预言家 + 1女巫 + 1猎人 + 1守卫 + 3平民
  - 狼人胜利：屠神或屠民
  - 好人胜利：所有狼人出局
  ''';
  
  @override
  List<RoleType> getExpandedGameRoles() => [
    RoleType.werewolf, RoleType.werewolf, RoleType.werewolf,  // 3狼人
    RoleType.seer, RoleType.witch, RoleType.hunter, RoleType.guard, // 4神职
    RoleType.villager, RoleType.villager, RoleType.villager,  // 3平民
  ];
}
```

### 性能指标

新架构经过全面的性能测试：

- **游戏引擎初始化**：9人局427μs，12人局232μs
- **技能系统执行**：平均2.62μs，TPS达38万+
- **事件系统处理**：添加平均0.69μs，查询平均219μs
- **内存使用**：大规模数据处理稳定，无泄漏问题
- **并发能力**：支持多游戏实例完全隔离运行

### 测试策略

```bash
# 单元测试
dart test test/game_config_test.dart         # 配置系统测试
dart test test/game_player_test.dart         # 玩家系统测试
dart test test/skill_system_test.dart        # 技能系统测试

# 集成测试  
dart test test/integration_test.dart         # 完整游戏流程测试

# 性能测试
dart test test/performance_test.dart         # 性能基准测试
dart test test/memory_test.dart              # 内存使用测试

# 覆盖率测试
dart test --coverage=coverage                # 生成覆盖率报告
```

### 开发指南

#### 添加新角色

1. **在 `role_implementations.dart` 中定义新角色**：
```dart
class NewRole extends GameRole {
  @override
  String get roleId => 'new_role';
  
  @override
  List<GameSkill> get skills => [NewRoleSkill()];
  
  @override
  String get rolePrompt => '你是新角色，具有特殊能力...';
}
```

2. **创建对应的技能**：
```dart
class NewRoleSkill extends GameSkill {
  @override
  String get skillId => 'new_role_skill';
  
  @override
  int get priority => 50;  // 技能优先级
  
  @override
  bool canCast(GamePlayer player, GameState state) {
    // 判断是否可以使用技能
  }
  
  @override
  Future<SkillResult> cast(GamePlayer player, GameState state) async {
    // 实现技能逻辑
  }
}
```

3. **在 `GameRoleFactory` 中注册**：
```dart
class GameRoleFactory {
  static GameRole createRoleFromType(RoleType roleType) {
    switch (roleType) {
      case RoleType.newRole:
        return NewRole();
      // ...
    }
  }
}
```

#### 扩展事件系统

1. **在对应的事件文件中添加新事件**：
```dart
class NewActionEvent extends GameEvent {
  final GamePlayer actor;
  final String action;
  
  NewActionEvent({
    required this.actor,
    required this.action,
  }) : super(
    eventId: 'new_action_${DateTime.now().millisecondsSinceEpoch}',
    type: GameEventType.playerAction,
    initiator: actor,
    visibility: EventVisibility.public,
  );
}
```

2. **设置正确的可见性规则**：
```dart
@override
bool isVisibleTo(GamePlayer player) {
  // 根据游戏规则定义可见性
  return visibility == EventVisibility.public ||
         (visibility == EventVisibility.roleSpecific && player.role.isWerewolf);
}
```

### 迁移注意事项

从旧架构升级时需要注意：

1. **GameParameters已删除**：使用GameAssembler和GameConfig替代
2. **Player重命名为GamePlayer**：支持多态的AIPlayer和HumanPlayer
3. **Role重命名为GameRole**：集成了提示词和技能系统
4. **三阶段简化为两阶段**：投票合并到Day阶段
5. **VotingState已删除**：投票逻辑集成到DayPhaseProcessor
6. **PromptManager已删除**：提示词集成到GameRole和GameSkill

## 故障排除

### 常见问题

1. **编译错误 "ConfigService未定义"**
   - 原因：旧的ConfigService已被删除
   - 解决：使用GameAssembler创建游戏

2. **测试失败 "Flutter dependency pollution"**
   - 原因：核心逻辑意外依赖Flutter框架
   - 解决：使用纯Dart测试，避免Flutter依赖

3. **性能问题**
   - 使用性能测试验证：`dart test test/performance_test.dart`
   - 检查内存使用：`dart test test/memory_test.dart`

### 调试技巧

```dart
// 启用调试日志
LoggerUtil.instance.d('调试信息');

// 检查游戏状态
print('当前阶段: ${gameState.currentPhase}');
print('存活玩家: ${gameState.alivePlayers.length}');
print('事件历史: ${gameState.eventHistory.length}');

// 验证技能效果
print('技能效果: ${gameState.skillEffects}');
print('技能使用次数: ${gameState.skillUsageCounts}');
```

### 最佳实践

1. **优先使用GameAssembler**：简化游戏创建流程
2. **遵循事件驱动**：所有游戏行为通过事件表示
3. **利用技能系统**：统一的技能架构便于扩展
4. **注意可见性规则**：确保玩家只能看到应该看到的信息
5. **使用多态玩家**：AI和人类玩家统一接口
6. **性能优先**：利用新架构的高性能特性

## 总结

新架构（v2.0.0）实现了真正的职责分离和自洽运行，提供了：
- **简化的接口**：4参数构造函数，易于使用
- **统一的抽象**：GamePlayer、GameSkill、GameRole一致性设计
- **优秀的性能**：微秒级响应，支持高并发
- **灵活的扩展**：模块化设计，便于添加新角色和功能
- **完整的测试**：单元测试、集成测试、性能测试全覆盖

这为构建高质量的狼人杀游戏应用奠定了坚实的基础。