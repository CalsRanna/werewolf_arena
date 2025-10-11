# Werewolf Arena - AI 驱动的狼人杀游戏引擎

[![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)](https://dart.dev/)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Werewolf Arena 是一个基于 Dart/Flutter 的 AI 驱动狼人杀游戏引擎，支持图形界面和命令行两种运行模式。游戏使用大语言模型（LLM）为 AI 玩家提供智能决策，支持经典狼人杀玩法的所有角色和规则。

## ✨ 特性

- 🎯 **双模式支持**: Flutter GUI 和命令行模式
- 🤖 **AI 驱动**: 集成多种 LLM（OpenAI GPT、Claude、本地模型等）
- 🏗️ **现代架构**: v2.0.0 采用四组件架构（GameConfig、GameScenario、GamePlayer、GameObserver）
- ⚡ **高性能**: 微秒级响应时间，支持大规模并发
- 🎲 **多场景支持**: 9人局、12人局等多种游戏配置
- 👥 **混合玩家**: 支持 AI 和人类玩家混合游戏
- 🔧 **高度可扩展**: 模块化设计，易于添加新角色和技能

## 🚀 快速开始

### 安装要求

- Dart SDK 3.0+
- Flutter 3.0+ （GUI 模式）

### 运行游戏

**Flutter GUI 模式（推荐）:**
```bash
flutter run
```

**命令行模式:**
```bash
dart run bin/console.dart
```

**自定义配置:**
```bash
dart run bin/console.dart --config config/custom_config.yaml --players 9
```

## 🎮 支持的角色

- 🐺 **狼人**: 夜晚击杀玩家
- 👥 **村民**: 白天投票讨论  
- 🔮 **预言家**: 夜晚查验身份
- 🧙‍♀️ **女巫**: 拥有解药和毒药
- 🛡️ **守卫**: 夜晚保护玩家
- 🏹 **猎人**: 死亡时可开枪带走一人

## 📖 使用指南

### 基本使用

```dart
import 'package:werewolf_arena/core/engine/game_assembler.dart';

// 1. 创建游戏
final gameEngine = await GameAssembler.assembleGame(
  scenarioId: '9_players',               // 9人局
  // configPath: 'path/to/config.yaml', // 可选：自定义配置
  // observer: customObserver,           // 可选：自定义观察者
);

// 2. 初始化游戏
await gameEngine.initializeGame();

// 3. 执行游戏循环
while (!gameEngine.isGameEnded) {
  await gameEngine.executeGameStep();
}
```

### 自定义配置

```dart
import 'package:werewolf_arena/core/domain/value_objects/game_config.dart';

final config = GameConfig(
  playerIntelligences: [
    PlayerIntelligence(
      baseUrl: 'https://api.openai.com/v1',
      apiKey: 'your-openai-key',
      modelId: 'gpt-4',
    ),
    PlayerIntelligence(
      baseUrl: 'https://api.anthropic.com/v1', 
      apiKey: 'your-claude-key',
      modelId: 'claude-3-sonnet-20240229',
    ),
    // 为每个 AI 玩家配置模型
  ],
  maxRetries: 3,
);
```

### 自定义观察者

```dart
import 'package:werewolf_arena/core/engine/game_observer.dart';

class MyGameObserver implements GameObserver {
  @override
  void onStateChange(GameState state) {
    print('游戏状态更新: ${state.currentPhase}');
  }
  
  @override
  void onGameEvent(GameEvent event) {
    print('游戏事件: ${event.eventType}');
  }
}
```

## 🏗️ 架构概览

### 核心组件

```
lib/core/
├── domain/                    # 领域模型（DDD架构）
│   ├── entities/              # 实体
│   │   ├── game_player.dart   # 游戏玩家（抽象基类）
│   │   ├── ai_player.dart     # AI玩家实现
│   │   ├── human_player.dart  # 人类玩家实现
│   │   └── game_role.dart     # 游戏角色（包含技能）
│   ├── skills/                # 技能系统
│   │   ├── game_skill.dart    # 技能抽象基类
│   │   └── night_skills.dart  # 夜晚技能实现
│   └── value_objects/         # 值对象
├── engine/                    # 游戏引擎
│   ├── game_engine_new.dart   # 新架构游戏引擎
│   ├── game_assembler.dart    # 游戏组装器
│   └── processors/            # 阶段处理器
├── events/                    # 事件系统
├── scenarios/                 # 游戏场景
└── state/                     # 状态管理
```

### 四组件架构

1. **GameConfig**: 游戏配置（AI模型、重试次数）
2. **GameScenario**: 游戏场景（角色分配、胜利条件）  
3. **GamePlayer**: 游戏玩家（AI/人类，每个有独立Driver）
4. **GameObserver**: 游戏观察者（事件监听、UI交互）

## 🧪 开发与测试

### 运行测试

```bash
# 单元测试
dart test

# 特定测试文件
dart test test/game_config_test.dart

# 覆盖率测试
dart test --coverage
```

### 代码质量检查

```bash
# 静态分析
dart analyze

# Flutter 分析
flutter analyze
```

### 性能测试

```bash
dart test test/performance_test.dart
dart test test/memory_test.dart
```

## 📊 性能指标

基于最新的性能测试结果：

- **游戏引擎初始化**: 9人局 427μs，12人局 232μs
- **技能系统执行**: 平均 2.62μs，TPS 38万+
- **事件系统处理**: 添加 0.69μs，查询 219μs
- **游戏循环性能**: 平均 0.4ms，吞吐量 1666 games/sec

## 🛠️ 开发指南

### 添加新角色

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

### 添加新技能

```dart
class CustomSkill extends GameSkill {
  @override
  String get skillId => 'custom_skill';
  
  @override
  String get prompt => '技能使用提示...';
  
  @override
  Future<SkillResult> cast(GamePlayer player, GameState state) async {
    // 技能执行逻辑
    return SkillResult(success: true, caster: player);
  }
}
```

### 创建自定义场景

```dart
class CustomScenario implements GameScenario {
  @override
  String get id => 'custom_scenario';
  
  @override
  Map<RoleType, int> get roleDistribution => {
    RoleType.werewolf: 2,
    RoleType.villager: 5,
    RoleType.seer: 1,
  };
}
```

## 📝 配置文件

默认配置位于 `config/default_config.yaml`：

```yaml
game:
  players:
    - name: "AI玩家1"
      intelligence:
        baseUrl: "https://api.openai.com/v1"
        apiKey: "your-api-key"
        modelId: "gpt-4"
    # 更多玩家配置...
  
  maxRetries: 3
  
scenario:
  id: "9_players"
  playerCount: 9
```

## 🔄 从 v1.x 迁移

如果你正在从 v1.x 版本升级，请参阅 [迁移指南](MIGRATION_GUIDE.md) 了解详细的迁移步骤和破坏性变更。

### 主要变更

- GameParameters 接口 → 四组件架构
- 三阶段游戏流程 → 两阶段流程（Night/Day）
- PlayerType 枚举 → 面向对象继承
- Action 系统 → 统一技能系统

## 🤝 贡献

欢迎贡献代码、报告问题或提出建议！

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

## 📜 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 🙏 致谢

感谢以下技术和社区的支持：

- [Dart](https://dart.dev/) - 高效的编程语言
- [Flutter](https://flutter.dev/) - 跨平台 UI 框架
- OpenAI GPT 系列模型
- Anthropic Claude 系列模型

## 📞 联系方式

- 问题反馈: [GitHub Issues](https://github.com/your-username/werewolf_arena/issues)
- 技术讨论: [GitHub Discussions](https://github.com/your-username/werewolf_arena/discussions)

---

**Werewolf Arena** - 让 AI 与人类在推理游戏中碰撞出智慧的火花！ 🎭🎯
