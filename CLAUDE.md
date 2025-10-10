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

### 双模式架构

项目采用共享核心逻辑 + 双适配器架构：
- **核心游戏逻辑**：`lib/core/` 包含游戏引擎、状态管理、事件系统等与 UI 无关的纯业务逻辑
- **Flutter GUI 层**：`lib/page/`、`lib/widget/` 提供图形界面，使用 `auto_route` 导航和 `signals` 状态管理
- **控制台适配器**：`lib/widget/console/console_adapter.dart` 将核心逻辑适配到命令行界面
- **游戏服务层**：`lib/services/game_service.dart` 作为 Flutter 友好的包装层，提供 Stream 事件流

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
dart run bin/console.dart --players 8
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
dart test test/game_event_test.dart          # 运行单个测试文件

# 代码生成（修改路由或数据模型后必须执行）
dart run build_runner build                  # 生成代码
dart run build_runner build --delete-conflicting-outputs  # 强制重新生成
dart run build_runner watch                  # 监听文件变化自动生成
```

## Architecture

### 目录结构

```
lib/
├── core/                    # 核心游戏逻辑（DDD架构，与 UI 无关）
│   ├── domain/              # 领域模型层
│   │   ├── entities/        # 实体
│   │   │   ├── player.dart           # 玩家实体(基类 + HumanPlayer)
│   │   │   ├── ai_player.dart        # AI玩家实体
│   │   │   └── role.dart             # 角色实体及所有角色实现
│   │   ├── value_objects/  # 值对象
│   │   │   ├── game_phase.dart       # 游戏阶段枚举
│   │   │   ├── game_status.dart      # 游戏状态枚举
│   │   │   ├── death_cause.dart      # 死亡原因枚举
│   │   │   ├── skill_type.dart       # 技能类型枚举
│   │   │   ├── event_visibility.dart # 事件可见性枚举
│   │   │   ├── game_event_type.dart  # 游戏事件类型枚举
│   │   │   ├── vote_type.dart        # 投票类型枚举
│   │   │   ├── speech_type.dart      # 发言类型枚举
│   │   │   ├── player_model_config.dart # 玩家模型配置
│   │   │   └── ai_personality.dart   # AI性格状态
│   │   └── enums/           # 其他枚举类型
│   │       ├── player_type.dart      # 玩家类型枚举
│   │       ├── role_type.dart        # 角色类型枚举
│   │       └── role_alignment.dart   # 角色阵营枚举
│   ├── events/             # 事件系统(CQRS/Event Sourcing)
│   │   ├── base/           # 事件基类
│   │   │   └── game_event.dart      # 事件基类和GameEventType
│   │   ├── player_events.dart        # 玩家相关事件
│   │   ├── skill_events.dart         # 技能相关事件
│   │   ├── phase_events.dart         # 阶段相关事件
│   │   └── system_events.dart        # 系统事件
│   ├── state/              # 状态管理
│   │   ├── game_state.dart          # 游戏状态容器(简化后)
│   │   ├── night_action_state.dart  # 夜晚行动状态
│   │   └── voting_state.dart        # 投票状态
│   ├── engine/             # 游戏引擎核心
│   │   ├── game_engine.dart         # 主游戏引擎(流程编排,简化后)
│   │   ├── game_observer.dart       # 游戏观察者接口
│   │   ├── game_parameters.dart     # 游戏参数接口
│   │   └── processors/              # 处理器模式
│   │       ├── phase_processor.dart      # 阶段处理器接口
│   │       ├── night_phase_processor.dart
│   │       ├── day_phase_processor.dart
│   │       ├── voting_phase_processor.dart
│   │       ├── action_processor.dart     # 行动处理器接口
│   │       ├── werewolf_action_processor.dart
│   │       ├── guard_action_processor.dart
│   │       ├── seer_action_processor.dart
│   │       └── witch_action_processor.dart
│   ├── scenarios/          # 游戏场景(重命名自rules)
│   │   ├── game_scenario.dart        # 场景抽象接口
│   │   ├── scenario_9_players.dart   # 9人局场景
│   │   ├── scenario_12_players.dart  # 12人局场景
│   │   └── scenario_registry.dart    # 场景注册表
│   ├── rules/              # 游戏规则引擎(新建)
│   │   ├── victory_conditions.dart  # 胜利条件判定
│   │   ├── action_validator.dart    # 行动合法性验证
│   │   └── logic_validator.dart     # 逻辑一致性验证
│   └── services/           # 领域服务(新建)
│       ├── player_order_service.dart     # 玩家顺序服务
│       ├── action_resolver_service.dart  # 行动解析服务
│       └── event_filter_service.dart     # 事件过滤服务
├── services/               # 服务层
│   ├── game_service.dart                 # 游戏服务（Flutter 包装层）
│   ├── config_service.dart               # 配置服务
│   ├── llm/                              # LLM 集成
│   │   ├── llm_service.dart              # LLM 服务
│   │   ├── prompt_manager.dart           # 提示词管理
│   │   ├── enhanced_prompts.dart         # 增强提示词
│   │   └── json_cleaner.dart             # JSON 清理工具
│   ├── config/             # 配置管理
│   │   ├── config.dart                   # 配置数据结构
│   │   └── config_loader.dart            # 配置加载器
│   └── logging/            # 日志系统
│       ├── logger.dart                   # 通用日志
│       └── player_logger.dart            # 玩家日志
├── page/                   # Flutter 页面（MVVM 架构）
│   ├── bootstrap/          # 启动页
│   ├── home/               # 主页
│   ├── game/               # 游戏页面
│   └── settings/           # 设置页面（包含 LLM 配置）
├── widget/                 # Flutter 组件
│   └── console/            # 控制台相关组件
│       ├── console_adapter.dart          # 控制台适配器
│       ├── game_console.dart             # 游戏控制台
│       └── console_callback_handler.dart # 控制台回调处理
├── router/                 # 路由配置（auto_route）
│   ├── router.dart                       # 路由定义
│   └── router.gr.dart                    # 生成的路由代码
├── di.dart                 # 依赖注入配置（GetIt）
├── main.dart               # Flutter 应用入口
└── util/                   # 工具类
    └── responsive.dart                   # 响应式布局工具

bin/
└── console.dart            # 命令行模式入口

config/
└── default_config.yaml     # 默认游戏配置
```

### Core Components

**GameEngine (`lib/core/engine/game_engine.dart`)**：重构后的游戏引擎核心，采用处理器模式管理游戏流程。主要负责阶段转换协调和处理器调度，通过观察者接口 `GameObserver` 与 UI 层解耦。具体游戏逻辑委托给专门的处理器实现。

**事件系统 (`lib/core/events/`)**：完整的事件驱动架构实现，按类型分为四个文件：
- `base/game_event.dart`：事件基类和核心类型定义
- `player_events.dart`：玩家相关事件（死亡、发言、投票、遗言、狼人讨论）
- `skill_events.dart`：技能相关事件（狼人击杀、守卫保护、预言家查验、女巫用药、猎人开枪）
- `phase_events.dart`：阶段相关事件（阶段转换、夜晚结果、发言顺序）
- `system_events.dart`：系统事件（游戏开始/结束、错误、法官宣布）

**GameState (`lib/core/state/game_state.dart`)**：简化后的游戏状态容器，采用组合模式。将复杂的夜晚行动和投票逻辑委托给 `NightActionState` 和 `VotingState`，胜利条件判定委托给 `VictoryConditions` 类。

**处理器模式 (`lib/core/engine/processors/`)**：新的模块化架构，将游戏逻辑分解为独立的处理器：
- **阶段处理器**：`NightPhaseProcessor`、`DayPhaseProcessor`、`VotingPhaseProcessor`
- **行动处理器**：`WerewolfActionProcessor`、`GuardActionProcessor`、`SeerActionProcessor`、`WitchActionProcessor`

**领域服务 (`lib/core/services/`)**：新抽取的业务逻辑服务：
- `PlayerOrderService`：管理玩家行动顺序逻辑
- `ActionResolverService`：处理夜晚行动结算和冲突解析
- `EventFilterService`：提供事件过滤和查询功能

**规则引擎 (`lib/core/rules/`)**：独立的游戏规则模块：
- `VictoryConditions`：胜利条件判定逻辑
- `ActionValidator`：行动合法性验证
- `LogicValidator`：逻辑一致性检查

**AI Players (`lib/core/domain/entities/ai_player.dart`)**：AI 玩家实现，使用 LLM 进行决策。基于可见事件和角色身份生成行动。通过 `processInformation` 更新知识，`chooseNightTarget`/`chooseVoteTarget` 做出决策，`generateStatement` 生成发言。

**实体系统 (`lib/core/domain/entities/`)**：领域驱动的实体设计：
- `Player`：玩家基类和人类玩家实现
- `AIPlayer`：AI玩家实体，集成LLM决策能力
- `Role`：角色实体及所有角色实现（狼人、预言家、女巫、猎人、守卫、平民）

**值对象和枚举 (`lib/core/domain/value_objects/` 和 `lib/core/domain/enums/`)**：细粒度的值对象设计，包括游戏阶段、状态、事件类型、死亡原因等13个专用枚举/值对象。

**LLM Integration (`lib/services/llm/llm_service.dart`)**：与大语言模型的集成层。支持 OpenAI API 调用，处理 JSON 响应解析和清理。`PromptManager` 管理提示词模板，`EnhancedPrompts` 提供场景特定的增强提示词。

**GameService (`lib/services/game_service.dart`)**：Flutter 友好的游戏服务包装层。实现 `GameObserver` 接口，将游戏事件转换为 Stream 事件流供 UI 监听。提供 `gameEvents`、`phaseChangeStream`、`playerActionStream` 等流。

**Dependency Injection (`lib/di.dart`)**：使用 `GetIt` 管理依赖注入。注册单例服务（`ConfigService`、`GameService`）和工厂创建的 ViewModel。

**Router (`lib/router/router.dart`)**：使用 `auto_route` 管理应用导航。包含启动页、主页、游戏页、设置页等路由。修改后需要运行 `build_runner` 重新生成 `router.gr.dart`。

**GameObserver (`lib/core/engine/game_observer.dart`)**：游戏观察者接口，定义游戏引擎与外部系统之间的通信协议。包含 `GameObserver` 基础接口、`GameObserverAdapter` 适配器类和 `CompositeGameObserver` 复合观察者，支持多个观察者同时监听游戏事件。

### Key Patterns

**领域驱动设计(DDD)**：采用DDD架构组织代码，按业务领域而非技术层次划分模块。包含领域实体、值对象、领域服务和应用服务，实现业务逻辑的清晰分层。

**事件驱动架构**：所有游戏行为通过事件（`GameEvent`）表示，事件存储在历史记录中。每个事件都有可见性规则，确保玩家只能看到他们应该看到的信息（如狼人能看到狼人讨论，预言家能看到查验结果）。事件按类型分为四个专门的文件。

**处理器模式**：将复杂的游戏逻辑分解为独立的处理器组件。每个阶段有对应的阶段处理器，每个角色技能有对应的行动处理器。支持灵活扩展新的游戏阶段和角色技能。

**组合状态管理**：使用组合模式管理复杂的游戏状态。`GameState` 组合了 `NightActionState` 和 `VotingState`，分别管理夜晚行动和投票逻辑，实现职责分离。

**阶段驱动流程**：游戏按固定阶段循环（夜晚 → 白天 → 投票 → 下一个夜晚）。每个阶段有特定的可执行行动：
- 夜晚：按顺序执行角色技能（狼人击杀 → 守卫守护 → 预言家查验 → 女巫用药）
- 白天：玩家依次发言讨论
- 投票：所有玩家同时投票，可能触发 PK 辩论

**角色技能系统**：每个角色通过 `Role` 接口定义能力。技能使用有条件限制（如女巫的药只能用一次，守卫不能连续守护同一人）。技能效果通过事件和状态元数据实现（如 `state.tonightVictim`）。

**回调解耦模式**：`GameEngine` 通过 `GameObserver` 接口与 UI 层通信，不直接依赖 Flutter。`GameService` 实现该接口并转换为 Stream，`ConsoleCallbackHandler` 实现该接口输出到控制台。这使核心逻辑可以被不同 UI 复用。

**MVVM 架构**（Flutter 层）：
- Model：`GameState`、`Player`、`Role` 等核心数据模型
- ViewModel：`page/*/view_model.dart` 使用 `signals` 进行状态管理
- View：`page/*/page.dart` Flutter 页面组件

**依赖注入**：使用 `GetIt` 单例模式管理服务生命周期，ViewModel 通过工厂模式创建。服务在 `DI.ensureInitialized()` 中注册。

### Configuration

游戏配置通过 `config/default_config.yaml` 文件控制：
- **角色分配**：定义每种角色的数量（狼人、预言家、女巫、猎人、守卫、平民）
- **LLM 设置**：配置 AI 使用的模型、API 密钥、提示词
- **游戏场景**：选择使用哪个预定义场景（9人局、12人局等）
- **行动顺序**：控制玩家发言和行动的顺序模式

配置通过 `GameParameters` 接口加载（`FlutterGameParameters` 用于 GUI，`ConsoleGameParameters` 用于控制台），支持运行时修改（Flutter GUI 提供设置页面）。

### Development Guidelines

#### 添加新角色
要添加新的游戏角色，请按以下步骤操作：

1. **在 `lib/core/domain/entities/role.dart` 中定义新角色类**：
   ```dart
   class NewRole extends Role {
     // 实现角色特有的能力逻辑
   }
   ```

2. **在 `lib/core/engine/processors/` 中创建对应的行动处理器**：
   ```dart
   class NewRoleActionProcessor extends ActionProcessor {
     @override
     Future<void> process(GameState state) async {
       // 实现角色的夜晚行动逻辑
     }
   }
   ```

3. **在 `GameEngine` 中注册新的处理器**

4. **在 `lib/core/events/skill_events.dart` 中添加相关事件类型**

#### 添加新游戏场景
要添加新的游戏场景配置：

1. **在 `lib/core/scenarios/` 中创建新的场景文件**：
   ```dart
   class CustomScenario implements GameScenario {
     // 实现场景配置逻辑
   }
   ```

2. **在 `lib/core/scenarios/scenario_registry.dart` 中注册场景**

#### 扩展事件系统
要添加新的事件类型：

1. **在对应的事件文件中添加新事件类**：
   - 玩家相关事件：`player_events.dart`
   - 技能相关事件：`skill_events.dart`
   - 阶段相关事件：`phase_events.dart`
   - 系统事件：`system_events.dart`

2. **确保事件继承自 `GameEvent` 基类**

3. **设置正确的 `EventVisibility` 规则**

#### 使用领域服务
重构后的架构提供了专门的领域服务：

- **PlayerOrderService**：用于获取玩家行动顺序
- **ActionResolverService**：用于处理复杂的行动冲突解析
- **EventFilterService**：用于查询和过滤游戏事件

这些服务可以在 `GameEngine`、处理器或其他服务中使用。

#### 状态管理最佳实践
- 使用 `NightActionState` 管理夜晚相关的临时状态
- 使用 `VotingState` 管理投票相关的状态
- 避免直接在 `GameState` 中添加新的状态字段
- 优先考虑使用组合模式扩展状态管理

#### 处理器开发指南
- 每个处理器应该只负责一个特定的游戏阶段或角色行动
- 处理器应该是无状态的，所有状态都应该存储在 GameState 中
- 使用事件来通知处理结果，而不是直接返回值
- 遵循单一职责原则，保持处理器的简洁性

### Game Flow

典型的游戏流程（单回合）：

1. **夜晚阶段**（`GameEngine._processNightPhase`）
   - 狼人行动：多个狼人先讨论，然后投票选择击杀目标
   - 守卫行动：选择守护对象（不能连续守护同一人）
   - 预言家行动：查验一名玩家的身份
   - 女巫行动：决定是否使用解药（救人）或毒药（毒人）
   - 夜晚结算：根据所有行动确定最终死亡名单

2. **白天阶段**（`GameEngine._processDayPhase`）
   - 公布夜晚结果：谁死了，或平安夜
   - 玩家依次发言：按特定顺序（从上一个死者的下一位开始）
   - AI 玩家基于可见事件和角色身份生成发言

3. **投票阶段**（`GameEngine._processVotingPhase`）
   - 所有存活玩家同时投票
   - 统计投票结果
   - 如果平票：进入 PK 辩论，平票者发言后其他人再投票
   - 出局玩家留遗言
   - 猎人出局时可开枪带走一人

4. **胜利检查**（`GameState.checkGameEnd`）
   - 好人胜利：所有狼人出局
   - 狼人胜利：屠神（所有神职出局）或屠民（所有平民出局），且狼人数量占优

### Testing

测试文件位于 `test/` 目录：
- `test/game_event_visibility_test.dart`：事件可见性规则测试
- `test/game_event_test.dart`：事件创建和处理测试
- 使用 `mocktail` 进行模拟测试

测试重点关注核心逻辑（事件系统、状态管理、胜利条件），而非 LLM 集成部分。