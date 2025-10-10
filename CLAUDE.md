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
├── core/                    # 核心游戏逻辑（与 UI 无关）
│   ├── engine/             # 游戏引擎
│   │   ├── game_engine.dart              # 主游戏引擎
│   │   └── game_observer.dart            # 游戏观察者接口
│   ├── state/              # 状态管理
│   │   ├── game_state.dart               # 游戏状态
│   │   └── game_event.dart               # 事件系统
│   ├── entities/           # 游戏实体
│   │   └── player/                       # 玩家相关
│   │       ├── player.dart               # 玩家基类
│   │       ├── ai_player.dart            # AI 玩家
│   │       ├── role.dart                 # 角色定义
│   │       └── ai_personality_state.dart # AI 性格状态
│   ├── rules/              # 游戏规则和场景
│   │   ├── game_scenario.dart            # 场景接口
│   │   ├── game_scenario_manager.dart    # 场景管理器
│   │   ├── scenarios_simple_9.dart       # 9人局场景
│   │   └── scenarios_standard_12.dart    # 12人局场景
│   └── logic/              # 逻辑检测
│       └── logic_contradiction_detector.dart
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

**GameEngine (`lib/core/engine/game_engine.dart`)**：游戏引擎核心，管理完整的游戏流程。控制阶段转换（夜晚→白天→投票），协调所有玩家行动，处理角色技能执行顺序。通过观察者接口 `GameObserver` 与 UI 层解耦。

**GameState (`lib/core/state/game_state.dart`)**：游戏状态容器，维护玩家列表、当前阶段、天数、事件历史等所有游戏数据。提供查询方法（如存活玩家、投票结果）和胜利条件检查（屠边规则）。使用 metadata 存储临时数据（如当晚的行动）。

**Event System (`lib/core/state/game_event.dart`)**：事件驱动架构的核心。所有游戏行为（发言、投票、技能使用）都表示为事件，每个事件都有可见性规则（`EventVisibility`）。玩家只能看到符合规则的事件，实现信息不对称。包括 `GameEvent` 基类和各种具体事件类型。

**AI Players (`lib/core/entities/player/ai_player.dart`)**：AI 玩家实现，使用 LLM 进行决策。`EnhancedAIPlayer` 基于可见事件和角色身份生成行动。通过 `processInformation` 更新知识，`chooseNightTarget`/`chooseVoteTarget` 做出决策，`generateStatement` 生成发言。

**Role System (`lib/core/entities/player/role.dart`)**：角色体系定义。每个角色（狼人、预言家、女巫、猎人、守卫、平民）都有独特的能力和胜利条件。角色分为狼人阵营和好人阵营（神职+平民）。角色能力通过 `canUseSkill` 检查使用条件。

**LLM Integration (`lib/services/llm/llm_service.dart`)**：与大语言模型的集成层。支持 OpenAI API 调用，处理 JSON 响应解析和清理。`PromptManager` 管理提示词模板，`EnhancedPrompts` 提供场景特定的增强提示词。

**GameService (`lib/services/game_service.dart`)**：Flutter 友好的游戏服务包装层。实现 `GameObserver` 接口，将游戏事件转换为 Stream 事件流供 UI 监听。提供 `gameEvents`、`phaseChangeStream`、`playerActionStream` 等流。

**Dependency Injection (`lib/di.dart`)**：使用 `GetIt` 管理依赖注入。注册单例服务（`ConfigService`、`GameService`）和工厂创建的 ViewModel。

**Router (`lib/router/router.dart`)**：使用 `auto_route` 管理应用导航。包含启动页、主页、游戏页、设置页等路由。修改后需要运行 `build_runner` 重新生成 `router.gr.dart`。

**GameObserver (`lib/core/engine/game_observer.dart`)**：游戏观察者接口，定义游戏引擎与外部系统之间的通信协议。包含 `GameObserver` 基础接口、`GameObserverAdapter` 适配器类和 `CompositeGameObserver` 复合观察者，支持多个观察者同时监听游戏事件。

### Key Patterns

**事件驱动架构**：所有游戏行为通过事件（`GameEvent`）表示，事件存储在历史记录中。每个事件都有可见性规则，确保玩家只能看到他们应该看到的信息（如狼人能看到狼人讨论，预言家能看到查验结果）。

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