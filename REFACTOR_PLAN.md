# 狼人杀游戏引擎重构计划

## 📊 当前进度状态

**✅ 阶段一: 准备工作和文件拆分 (已完成)**
- 📅 完成日期: 2025-10-10
- 🎯 状态: 所有6个任务已完成
- ✅ 成果: DDD目录结构已建立，文件拆分完成

**⏳ 阶段二: 状态管理重构 (待开始)**
- 🎯 状态: 准备就绪，可以开始执行
- 📋 任务: 3个子任务待完成

**⏸️ 阶段三: 引擎核心重构 (待开始)**

**⏸️ 阶段四: 新增服务和工具 (待开始)**

**⏸️ 阶段五: 导入语句修复和测试 (待开始)**

**⏸️ 阶段六: 清理和文档更新 (待开始)**

---

## 📋 重构目标

将当前混乱的 `lib/core/` 目录重构为清晰的领域驱动设计(DDD)架构,提高代码的可维护性、可测试性和可扩展性。

## 🎯 核心原则

- **单一职责原则**: 每个类只负责一件事
- **开闭原则**: 对扩展开放,对修改封闭
- **依赖倒置原则**: 依赖抽象而非具体实现
- **领域驱动设计**: 按业务领域而非技术层次组织代码

## 📐 目标架构

```
lib/core/                          # 狼人杀游戏引擎核心
├── domain/                        # 领域模型层
│   ├── entities/                  # 实体
│   │   ├── player.dart           # 玩家实体(基类 + HumanPlayer)
│   │   ├── ai_player.dart        # AI玩家实体
│   │   └── role.dart             # 角色实体及所有角色实现
│   ├── value_objects/            # 值对象
│   │   ├── game_phase.dart       # 游戏阶段枚举
│   │   ├── game_status.dart      # 游戏状态枚举
│   │   ├── death_cause.dart      # 死亡原因枚举
│   │   ├── skill_type.dart       # 技能类型枚举
│   │   ├── event_visibility.dart # 事件可见性枚举
│   │   └── player_model_config.dart  # 玩家模型配置
│   └── enums/                    # 其他枚举类型
│       ├── player_type.dart
│       ├── role_type.dart
│       ├── role_alignment.dart
│       ├── vote_type.dart
│       └── speech_type.dart
│
├── events/                       # 事件系统(CQRS/Event Sourcing)
│   ├── base/
│   │   ├── game_event.dart          # 事件基类和GameEventType
│   │   └── event_executor.dart      # 事件执行器接口
│   ├── player_events.dart       # 玩家相关事件
│   │   # - DeadEvent, SpeakEvent, VoteEvent, LastWordsEvent
│   ├── skill_events.dart        # 技能相关事件
│   │   # - WerewolfKillEvent, GuardProtectEvent, SeerInvestigateEvent
│   │   # - WitchHealEvent, WitchPoisonEvent, HunterShootEvent
│   ├── phase_events.dart        # 阶段相关事件
│   │   # - PhaseChangeEvent, NightResultEvent, SpeechOrderAnnouncementEvent
│   └── system_events.dart       # 系统事件
│       # - GameStartEvent, GameEndEvent, SystemErrorEvent, JudgeAnnouncementEvent
│
├── state/                        # 状态管理
│   ├── game_state.dart          # 游戏状态容器(简化后)
│   ├── night_action_state.dart  # 夜晚行动状态
│   └── voting_state.dart        # 投票状态
│
├── engine/                       # 游戏引擎核心
│   ├── game_engine.dart         # 主引擎(流程编排,简化后)
│   ├── game_observer.dart       # 观察者接口(保持不变)
│   ├── processors/              # 处理器模式
│   │   ├── phase_processor.dart      # 阶段处理器接口
│   │   ├── night_phase_processor.dart
│   │   ├── day_phase_processor.dart
│   │   ├── voting_phase_processor.dart
│   │   ├── action_processor.dart     # 行动处理器接口
│   │   ├── werewolf_action_processor.dart
│   │   ├── guard_action_processor.dart
│   │   ├── seer_action_processor.dart
│   │   └── witch_action_processor.dart
│   └── game_parameters.dart     # 游戏参数接口
│
├── scenarios/                    # 游戏场景(重命名自rules)
│   ├── game_scenario.dart            # 场景抽象接口
│   ├── scenario_9_players.dart       # 9人局场景
│   ├── scenario_12_players.dart      # 12人局场景
│   └── scenario_registry.dart        # 场景注册表
│
├── rules/                        # 游戏规则引擎(新建)
│   ├── victory_conditions.dart  # 胜利条件判定
│   └── action_validator.dart    # 行动合法性验证
│
└── services/                     # 领域服务(新建)
    ├── player_order_service.dart     # 玩家顺序服务
    ├── action_resolver_service.dart  # 行动解析服务
    └── event_filter_service.dart     # 事件过滤服务
```

## 🔄 重构任务清单

### 阶段一: 准备工作和文件拆分 (基础重构)

#### Task 1.1: 创建新目录结构 ✅
- [x] 创建 `lib/core/domain/entities/` 目录
- [x] 创建 `lib/core/domain/value_objects/` 目录
- [x] 创建 `lib/core/domain/enums/` 目录
- [x] 创建 `lib/core/events/base/` 目录
- [x] 创建 `lib/core/state/` 目录
- [x] 创建 `lib/core/engine/processors/` 目录
- [x] 创建 `lib/core/scenarios/` 目录
- [x] 创建 `lib/core/rules/` 目录
- [x] 创建 `lib/core/services/` 目录

#### Task 1.2: 拆分枚举类型到独立文件 ✅
- [x] 从 `game_state.dart` 提取 `GamePhase` 到 `domain/value_objects/game_phase.dart`
- [x] 从 `game_state.dart` 提取 `GameStatus` 到 `domain/value_objects/game_status.dart`
- [x] 从 `game_state.dart` 提取 `EventVisibility` 到 `domain/value_objects/event_visibility.dart`
- [x] 从 `game_state.dart` 提取 `GameEventType` 到 `domain/value_objects/game_event_type.dart`
- [x] 从 `game_event.dart` 提取 `DeathCause` 到 `domain/value_objects/death_cause.dart`
- [x] 从 `game_event.dart` 提取 `SkillType` 到 `domain/value_objects/skill_type.dart`
- [x] 从 `game_event.dart` 提取 `VoteType` 到 `domain/value_objects/vote_type.dart`
- [x] 从 `game_event.dart` 提取 `SpeechType` 到 `domain/value_objects/speech_type.dart`
- [x] 从 `role.dart` 提取 `RoleType` 到 `domain/enums/role_type.dart`
- [x] 从 `role.dart` 提取 `RoleAlignment` 到 `domain/enums/role_alignment.dart`
- [x] 从 `player.dart` 提取 `PlayerType` 到 `domain/enums/player_type.dart`
- [x] 从 `player.dart` 提取 `PlayerModelConfig` 到 `domain/value_objects/player_model_config.dart`

#### Task 1.3: 拆分事件类到独立文件 ✅
- [x] 创建 `events/base/game_event.dart`,移动 `GameEvent` 基类
- [x] 创建 `events/player_events.dart`,移动:
  - `DeadEvent`
  - `SpeakEvent`
  - `VoteEvent`
  - `LastWordsEvent`
  - `WerewolfDiscussionEvent`
- [x] 创建 `events/skill_events.dart`,移动:
  - `WerewolfKillEvent`
  - `GuardProtectEvent`
  - `SeerInvestigateEvent`
  - `WitchHealEvent`
  - `WitchPoisonEvent`
  - `HunterShootEvent`
- [x] 创建 `events/phase_events.dart`,移动:
  - `PhaseChangeEvent`
  - `NightResultEvent`
  - `SpeechOrderAnnouncementEvent`
- [x] 创建 `events/system_events.dart`,移动:
  - `GameStartEvent`
  - `GameEndEvent`
  - `SystemErrorEvent`
  - `JudgeAnnouncementEvent`
- [x] 更新所有事件类的导入语句
- [x] 删除原 `core/engine/game_event.dart` (内容已全部迁移)

#### Task 1.4: 移动玩家相关文件 ✅
- [x] 移动 `core/player/player.dart` 到 `core/domain/entities/player.dart`
- [x] 移动 `core/player/ai_player.dart` 到 `core/domain/entities/ai_player.dart`
- [x] 移动 `core/player/role.dart` 到 `core/domain/entities/role.dart`
- [x] 移动 `core/player/personality.dart` 到 `core/domain/value_objects/ai_personality.dart`
- [x] 更新所有引用这些文件的导入语句
- [x] 删除空的 `core/player/` 目录

#### Task 1.5: 重组场景相关文件 ✅
- [x] 移动 `core/engine/game_scenario.dart` 到 `core/scenarios/game_scenario.dart`
- [x] 移动 `core/rules/scenarios_simple_9.dart` 到 `core/scenarios/scenario_9_players.dart`
- [x] 重命名类 `Simple9PlayersScenario` 为 `Standard9PlayersScenario`
- [x] 移动 `core/rules/scenarios_standard_12.dart` 到 `core/scenarios/scenario_12_players.dart`
- [x] 重命名类 `Standard12PlayersScenario` 为 `Standard12PlayersScenario`
- [x] 移动 `core/rules/game_scenario_manager.dart` 到 `core/scenarios/scenario_registry.dart`
- [x] 重命名类 `GameScenarioManager` 为 `ScenarioRegistry`
- [x] 更新所有场景相关的导入语句
- [x] 删除空的 `core/rules/` 目录(暂时)

#### Task 1.6: 移动和重命名其他文件 ✅
- [x] 移动 `core/engine/game_parameters.dart` 到 `core/engine/game_parameters.dart` (保持不变)
- [x] 移动 `core/logic/logic_contradiction_detector.dart` 到 `core/rules/logic_validator.dart`
- [x] 重命名类 `LogicContradictionDetector` 为 `LogicValidator`
- [x] 更新所有相关导入语句

### 阶段二: 状态管理重构

#### Task 2.1: 创建专门的状态管理类
- [ ] 创建 `state/night_action_state.dart`
  - 定义 `NightActionState` 类
  - 从 `GameState` 迁移夜晚行动相关字段和方法:
    - `tonightVictim`, `tonightProtected`, `tonightPoisoned`, `killCancelled`
    - `setTonightVictim()`, `setTonightProtected()`, `setTonightPoisoned()`
    - `cancelTonightKill()`, `clearNightActions()`
- [ ] 创建 `state/voting_state.dart`
  - 定义 `VotingState` 类
  - 从 `GameState` 迁移投票相关字段和方法:
    - `votes`, `totalVotes`, `requiredVotes`
    - `addVote()`, `clearVotes()`, `getVoteResults()`
    - `getVoteTarget()`, `getTiedPlayers()`

#### Task 2.2: 简化 GameState
- [ ] 在 `GameState` 中添加 `NightActionState` 和 `VotingState` 实例
- [ ] 移除已迁移到状态类的字段和方法
- [ ] 添加委托方法或getter以保持向后兼容
- [ ] 更新 `toJson()` 和 `fromJson()` 方法
- [ ] 移动 `GameState` 到 `state/game_state.dart`

#### Task 2.3: 提取胜利条件判定逻辑
- [ ] 创建 `rules/victory_conditions.dart`
- [ ] 定义 `VictoryConditions` 类
- [ ] 从 `GameState.checkGameEnd()` 提取胜利判定逻辑
- [ ] 实现 `checkWerewolvesWin()`, `checkGoodGuysWin()` 等方法
- [ ] 更新 `GameState.checkGameEnd()` 调用新的 `VictoryConditions`

### 阶段三: 引擎核心重构

#### Task 3.1: 创建处理器接口
- [ ] 创建 `engine/processors/phase_processor.dart`
  - 定义 `PhaseProcessor` 抽象类
  - 定义 `process(GameState state)` 方法
- [ ] 创建 `engine/processors/action_processor.dart`
  - 定义 `ActionProcessor` 抽象类
  - 定义 `process(GameState state)` 方法

#### Task 3.2: 实现阶段处理器
- [ ] 创建 `engine/processors/night_phase_processor.dart`
  - 从 `GameEngine._processNightPhase()` 提取逻辑
  - 实现夜晚阶段流程编排
  - 依赖行动处理器列表
- [ ] 创建 `engine/processors/day_phase_processor.dart`
  - 从 `GameEngine._processDayPhase()` 提取逻辑
  - 实现白天阶段流程(公布结果、讨论)
- [ ] 创建 `engine/processors/voting_phase_processor.dart`
  - 从 `GameEngine._processVotingPhase()` 提取逻辑
  - 实现投票阶段流程(收集投票、解析结果、PK)

#### Task 3.3: 实现行动处理器
- [ ] 创建 `engine/processors/werewolf_action_processor.dart`
  - 从 `GameEngine.processWerewolfActions()` 提取逻辑
  - 处理狼人讨论和投票
- [ ] 创建 `engine/processors/guard_action_processor.dart`
  - 从 `GameEngine.processGuardActions()` 提取逻辑
  - 处理守卫守护行动
- [ ] 创建 `engine/processors/seer_action_processor.dart`
  - 从 `GameEngine.processSeerActions()` 提取逻辑
  - 处理预言家查验行动
- [ ] 创建 `engine/processors/witch_action_processor.dart`
  - 从 `GameEngine.processWitchActions()` 提取逻辑
  - 处理女巫解药和毒药行动

#### Task 3.4: 重构 GameEngine
- [ ] 在 `GameEngine` 中注入阶段处理器
- [ ] 简化 `_processGamePhase()` 使用处理器模式
- [ ] 移除已提取到处理器的方法
- [ ] 保留核心编排逻辑和观察者通知
- [ ] 保留错误处理和生命周期管理

### 阶段四: 新增服务和工具

#### Task 4.1: 创建玩家顺序服务
- [ ] 创建 `services/player_order_service.dart`
- [ ] 从 `GameEngine._getActionOrder()` 提取逻辑
- [ ] 实现 `PlayerOrderService` 类
  - `getActionOrder()`: 获取玩家行动顺序
  - `findLastDeadPlayer()`: 查找最后死亡的玩家
  - `reorderFromStartingPoint()`: 从起点重排序

#### Task 4.2: 创建行动解析服务
- [ ] 创建 `services/action_resolver_service.dart`
- [ ] 从 `GameEngine.resolveNightActions()` 提取逻辑
- [ ] 实现夜晚行动结算:
  - 处理击杀、保护、治疗、毒杀的优先级
  - 判断最终死亡结果

#### Task 4.3: 创建事件过滤服务
- [ ] 创建 `services/event_filter_service.dart`
- [ ] 实现 `EventFilterService` 类
  - `getEventsForPlayer()`: 获取玩家可见事件
  - `filterByVisibility()`: 按可见性过滤事件
  - `filterByPhase()`: 按阶段过滤事件
  - `filterByType()`: 按类型过滤事件

#### Task 4.4: 创建行动验证器
- [ ] 创建 `rules/action_validator.dart`
- [ ] 实现 `ActionValidator` 类
- [ ] 验证各种行动的合法性:
  - 守卫不能连续守同一人
  - 女巫的药是否已用
  - 猎人是否已开枪
  - 玩家是否存活等

### 阶段五: 导入语句修复和测试

#### Task 5.1: 全局导入语句更新
- [ ] 更新 `lib/services/` 中的导入语句
- [ ] 更新 `lib/page/` 中的导入语句
- [ ] 更新 `lib/widget/` 中的导入语句
- [ ] 更新 `bin/console.dart` 中的导入语句
- [ ] 更新 `test/` 中的导入语句

#### Task 5.2: 运行测试和修复
- [ ] 运行 `dart analyze` 检查静态分析错误
- [ ] 修复所有分析错误
- [ ] 运行 `dart test` 执行测试
- [ ] 修复所有测试失败
- [ ] 确保所有测试通过

#### Task 5.3: 验证功能完整性
- [ ] 测试控制台模式游戏流程
- [ ] 测试 Flutter GUI 模式游戏流程
- [ ] 验证所有角色行动正常
- [ ] 验证事件系统正常工作
- [ ] 验证观察者模式正常工作

### 阶段六: 清理和文档更新

#### Task 6.1: 删除旧文件
- [ ] 删除 `core/engine/game_event.dart` (已拆分)
- [ ] 删除 `core/player/` 目录 (已迁移)
- [ ] 删除 `core/rules/` 目录下的旧场景文件 (已迁移)
- [ ] 删除 `core/logic/` 目录 (已迁移)

#### Task 6.2: 更新文档
- [ ] 更新 `CLAUDE.md` 中的架构说明
- [ ] 更新目录结构描述
- [ ] 更新核心组件说明
- [ ] 添加新的架构模式说明
- [ ] 更新开发指南

#### Task 6.3: 添加代码注释
- [ ] 为所有新创建的类添加详细注释
- [ ] 为所有公共方法添加文档注释
- [ ] 添加使用示例
- [ ] 添加架构设计说明

## 📊 重构验收标准

### 代码质量
- [ ] 所有文件符合 Dart 代码规范
- [ ] 没有静态分析警告或错误
- [ ] 所有类和方法都有适当的文档注释
- [ ] 没有代码重复(DRY原则)

### 架构质量
- [ ] 每个类职责单一明确
- [ ] 依赖方向正确(依赖抽象)
- [ ] 没有循环依赖
- [ ] 模块边界清晰

### 功能完整性
- [ ] 所有原有功能正常工作
- [ ] 所有测试用例通过
- [ ] 控制台模式运行正常
- [ ] Flutter GUI 模式运行正常

### 可维护性
- [ ] 新增角色只需添加新的处理器
- [ ] 新增场景只需实现场景接口
- [ ] 修改规则不影响引擎核心
- [ ] 易于定位和修复问题

## 🎯 预期收益

1. **代码组织**: 文件数量增加,但每个文件职责清晰,平均行数减少
2. **可维护性**: 修改某个功能只需修改对应模块,影响范围小
3. **可测试性**: 每个处理器可以独立测试,不依赖完整的游戏引擎
4. **可扩展性**: 新增角色、场景、规则更容易,符合开闭原则
5. **可读性**: 新开发者更容易理解代码结构和业务逻辑

## 📝 注意事项

1. **向后兼容**: 保持公共API不变,避免影响上层代码
2. **渐进式重构**: 分阶段进行,每个阶段都保证代码可运行
3. **测试保障**: 每完成一个阶段都运行测试,确保功能正常
4. **提交粒度**: 每完成一个Task就提交,保持提交历史清晰
5. **文档同步**: 代码重构的同时更新相关文档

## 🔄 执行顺序

严格按照以下顺序执行:
1. 阶段一 → 阶段二 → 阶段三 → 阶段四 → 阶段五 → 阶段六
2. 每个阶段内的Task可以部分并行,但建议按顺序执行
3. 完成每个Task后运行 `dart analyze` 检查错误
4. 完成每个阶段后运行 `dart test` 验证功能

---

**重构开始日期**: 2025-10-10
**阶段一完成日期**: 2025-10-10
**预计完成日期**: 待定
**负责人**: Claude Code

## 📝 执行日志

### 2025-10-10 (阶段一完成)
✅ **阶段一: 准备工作和文件拆分** - 已完成
- 成功建立DDD目录结构
- 完成所有枚举类型拆分 (13个枚举)
- 完成所有事件类拆分 (4个事件文件)
- 完成玩家相关文件移动 (4个文件)
- 完成场景相关文件重组和重命名
- 完成其他文件移动和类重命名
- 更新了所有相关的导入语句和引用

**下一步**: 开始阶段二 - 状态管理重构
