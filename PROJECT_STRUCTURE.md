# 狼人杀竞技场 - 项目结构

项目采用清晰的分层架构，遵循 DDD (Domain-Driven Design) 和 Clean Architecture 原则。

## 📁 项目结构

```
werewolf_arena/
├── bin/                         # 可执行文件
│   └── werewolf_arena.dart     # 主程序入口
├── lib/                         # Dart 源代码
│   ├── core/                   # 核心游戏逻辑 (Domain Layer)
│   │   ├── engine/             # 游戏引擎
│   │   │   ├── game_engine.dart
│   │   │   └── game_engine_callbacks.dart
│   │   ├── state/              # 游戏状态管理
│   │   │   ├── game_state.dart
│   │   │   └── game_event.dart
│   │   ├── rules/              # 游戏规则和场景
│   │   │   ├── game_scenario.dart
│   │   │   ├── game_scenario_manager.dart
│   │   │   ├── scenarios_standard_12.dart
│   │   │   └── scenarios_simple_9.dart
│   │   └── logic/              # 游戏逻辑处理
│   │       └── logic_contradiction_detector.dart
│   ├── entities/               # 实体层
│   │   └── player/             # 玩家相关实体
│   │       ├── player.dart
│   │       ├── ai_player.dart
│   │       ├── ai_personality_state.dart
│   │       └── role.dart
│   ├── infrastructure/         # 基础设施层 (Infrastructure Layer)
│   │   ├── llm/               # LLM 服务
│   │   │   ├── llm_service.dart
│   │   │   ├── prompt_manager.dart
│   │   │   ├── enhanced_prompts.dart
│   │   │   └── json_cleaner.dart
│   │   ├── logging/           # 日志系统
│   │   │   ├── logger.dart
│   │   │   └── player_logger.dart
│   │   └── config/            # 配置管理
│   │       ├── config.dart
│   │       └── config_loader_old.dart
│   ├── presentation/          # 表现层 (Presentation Layer)
│   │   ├── console/           # 控制台 UI
│   │   │   ├── game_console.dart
│   │   │   └── console_callback_handler.dart
│   │   └── cli/               # 命令行接口
│   │       └── werewolf_arena.dart
│   ├── shared/                # 共享工具
│   │   └── random_helper.dart
│   └── werewolf_arena.dart     # 主入口文件
├── test/                       # 测试文件
├── config/                     # 配置文件
│   └── *.yaml
└── pubspec.yaml               # Dart 项目配置
```

## 🏗️ 架构层次说明

### 1. Core Layer (核心层)
**职责**: 纯粹的游戏逻辑，不依赖任何外部系统
- **Engine**: 游戏引擎，管理游戏流程和状态转换
- **State**: 游戏状态和事件定义
- **Rules**: 游戏规则、场景和游戏配置
- **Logic**: 游戏逻辑处理，如矛盾检测

### 2. Entities Layer (实体层)
**职责**: 游戏中的核心实体对象
- **Player**: 玩家基础类和 AI 玩家
- **Role**: 角色定义和能力
- **AI State**: AI 玩家的状态和性格

### 3. Infrastructure Layer (基础设施层)
**职责**: 外部依赖和技术实现
- **LLM**: 语言模型服务集成
- **Logging**: 日志记录系统
- **Config**: 配置文件管理

### 4. Presentation Layer (表现层)
**职责**: 用户界面和交互
- **Console**: 控制台界面和格式化输出
- **CLI**: 命令行参数处理和应用启动

### 5. Shared Layer (共享层)
**职责**: 通用工具和辅助功能
- **Random Helper**: 随机数生成和辅助工具

## 🔗 依赖关系

```
Presentation → Core → Entities
     ↓              ↓       ↓
Infrastructure ←─────────┘
     ↑
   Shared
```

- **Core** 不依赖任何其他层级，是最纯净的业务逻辑
- **Presentation** 依赖 Core 和 Infrastructure
- **Infrastructure** 提供技术支持给上层
- **Entities** 被所有层级共享
- **Shared** 提供通用工具

## 🎯 重构优势

1. **清晰的职责分离**: 每个模块都有明确的单一职责
2. **高内聚低耦合**: 相关功能聚集在一起，模块间依赖最小化
3. **可测试性**: 核心逻辑可以独立测试，不依赖外部系统
4. **可扩展性**: 可以轻松添加新的表现层（如 Web UI、GUI）
5. **可维护性**: 代码结构清晰，易于理解和修改
6. **依赖注入**: 通过回调系统实现松耦合

## 📦 模块通信

- **事件驱动**: 游戏引擎通过回调通知外部事件
- **依赖注入**: 回调处理器通过构造函数注入
- **接口隔离**: 通过接口定义模块间的通信协议

## 🚀 使用示例

```dart
// 创建游戏引擎
final engine = GameEngine(
  configManager: configManager,
  callbacks: consoleCallbackHandler,
);

// 启动游戏
await engine.startGame();

// 执行游戏步骤
while (!engine.isGameEnded) {
  await engine.executeGameStep();
}
```

这种架构使得游戏逻辑与 UI 完全分离，你可以轻松替换不同的表现层而不影响核心游戏逻辑。