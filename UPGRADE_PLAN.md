# Werewolf Arena 游戏引擎架构升级详细计划

## 文档信息
- **版本**: 2.0.0
- **日期**: 2025-10-10
- **目标**: 基于game_engine_refactoring.md制定详细的升级计划

## 升级概述

本次升级将重构游戏引擎，实现真正的职责分离和自洽运行。核心变化包括：
- 从复杂的GameParameters接口简化为4个独立组件
- 重构GamePlayer为多态架构（AIPlayer和HumanPlayer）
- 统一技能系统，消除概念碎片化
- 每个玩家拥有独立的PlayerDriver
- 简化为两阶段游戏流程（Night和Day）
- GameStatus重命名为GameEngineStatus，由引擎管理

## 详细升级计划

### 阶段1：基础设施和核心接口定义（预计2-3天）

#### 1.1 创建新的配置系统（4小时）
**[✓] 任务1.1.1**: 创建GameConfig类
- ✓ 在`lib/core/domain/value_objects/`目录下创建`game_config.dart`
- ✓ 实现GameConfig类，包含playerIntelligences和maxRetries
- ✓ 实现PlayerIntelligence类，包含baseUrl、apiKey、modelId
- ✓ 创建`game_engine_status.dart`，定义引擎状态枚举（waiting, playing, ended）
- ✓ 添加copyWith方法用于创建配置副本

**[✓] 任务1.1.2**: 创建配置加载工具
- ✓ 在`lib/core/domain/value_objects/`目录下创建`config_loader.dart`
- ✓ 实现从YAML配置文件转换为GameConfig的逻辑
- ✓ 实现配置验证逻辑

**[✓] 任务1.1.3**: 运行代码分析
```bash
dart analyze
```

#### 1.2 重构GameScenario接口（4小时）
**[✓] 任务1.2.1**: 简化GameScenario接口
- ✓ 移除initialize、getNextActionRole等方法
- ✓ 添加rule字段用于用户界面展示
- ✓ 添加getExpandedRoles方法用于角色列表获取
- ✓ 创建VictoryResult类替代GameEndResult

**[✓] 任务1.2.2**: 更新现有场景实现
- ✓ 更新scenario_9_players.dart实现新接口
- ✓ 更新scenario_12_players.dart实现新接口
- ✓ 确保所有场景都有完整的rule描述
- ✓ 更新RoleType枚举，添加具体角色类型

**[✓] 任务1.2.3**: 删除ScenarioRegistry
- ✓ 删除scenario_registry.dart文件
- ✓ 移除所有对ScenarioRegistry的引用
- ✓ 暂时注释掉相关功能，等待阶段4重构

**[✓] 任务1.2.4**: 运行代码分析
```bash
dart analyze
```

#### 1.3 创建PlayerDriver架构（6小时）
**任务1.3.1**: 创建PlayerDriver抽象接口
- 在`lib/core/drivers/`目录下创建`player_driver.dart`
- 定义generateSkillResponse抽象方法
- 设计统一的AI响应接口

**任务1.3.2**: 实现AIPlayerDriver
- 在`lib/core/drivers/`目录下创建`ai_player_driver.dart`
- 集成OpenAIService用于AI决策
- 实现游戏上下文构建逻辑
- 实现JSON响应清理逻辑

**任务1.3.3**: 实现HumanPlayerDriver
- 在`lib/core/drivers/`目录下创建`human_player_driver.dart`
- 实现等待人类输入的逻辑框架
- 预留UI集成接口

**任务1.3.4**: 运行代码分析
```bash
dart analyze
```

#### 1.4 创建技能系统基础架构（8小时）
**任务1.4.1**: 创建GameSkill抽象类
- 在`lib/core/skills/`目录下创建`game_skill.dart`
- 定义技能基本信息（skillId、name、description、priority）
- 定义技能提示词（prompt）
- 定义canCast和cast抽象方法

**任务1.4.2**: 创建SkillResult类
- 在`lib/core/skills/`目录下创建`skill_result.dart`
- 简化设计，只包含success、caster、target
- 移除复杂的metadata设计

**任务1.4.3**: 创建SkillProcessor类
- 在`lib/core/skills/`目录下创建`skill_processor.dart`
- 实现技能结果处理和冲突解析逻辑
- 处理保护vs击杀冲突

**任务1.4.4**: 运行代码分析
```bash
dart analyze
```

### 阶段2：实体重构（预计3-4天）

#### 2.1 重构GamePlayer架构（8小时）
**任务2.1.1**: 重构Player为GamePlayer抽象基类
- 重命名`lib/core/domain/entities/player.dart`为`game_player.dart`
- 将Player改为抽象基类GamePlayer
- 添加driver属性
- 添加executeSkill抽象方法
- 添加事件处理方法

**任务2.1.2**: 创建AIPlayer实现
- 在`lib/core/domain/entities/`目录下创建`ai_player.dart`
- 继承GamePlayer，使用AIPlayerDriver
- 实现executeSkill方法
- 实现事件处理逻辑

**任务2.1.3**: 创建HumanPlayer实现
- 在`lib/core/domain/entities/`目录下创建`human_player.dart`
- 继承GamePlayer，使用HumanPlayerDriver
- 实现等待用户输入的机制（不使用StreamController）
- 实现submitSkillResult方法用于外部调用

**任务2.1.4**: 删除PlayerType枚举
- 删除`lib/core/domain/enums/player_type.dart`
- 移除所有对PlayerType的引用
- 使用is操作符进行类型检查

**任务2.1.5**: 运行代码分析
```bash
dart analyze
```

#### 2.2 重构GameRole架构（8小时）
**任务2.2.1**: 重构Role为GameRole
- 重命名`lib/core/domain/entities/role.dart`为`game_role.dart`
- 整合Prompt系统，添加rolePrompt属性
- 添加技能列表属性（skills）
- 添加getAvailableSkills方法
- 添加事件响应方法

**任务2.2.2**: 更新所有角色实现
- 更新所有角色类继承GameRole
- 为每个角色配置相应的技能列表
- 实现getAvailableSkills方法
- 添加角色特定的prompt

**任务2.2.3**: 创建基础技能实现
- 在`lib/core/skills/`目录下创建`base_skills.dart`
- 实现WerewolfKillSkill、GuardProtectSkill等基础技能
- 为每个技能配置适当的priority和prompt

**任务2.2.4**: 运行代码分析
```bash
dart analyze
```

#### 2.3 创建具体技能实现（6小时）
**任务2.3.1**: 创建夜晚技能
- 在`lib/core/skills/`目录下创建`night_skills.dart`
- 实现WerewolfKillSkill、GuardProtectSkill、SeerCheckSkill、WitchPotionSkill
- 配置适当的执行优先级

**任务2.3.2**: 创建白天技能
- 在`lib/core/skills/`目录下创建`day_skills.dart`
- 实现SpeakSkill、DiscussSkill等白天相关技能

**任务2.3.3**: 创建投票技能
- 在`lib/core/skills/`目录下创建`vote_skills.dart`
- 实现VoteSkill、PkVoteSkill等投票相关技能

**任务2.3.4**: 运行代码分析
```bash
dart analyze
```

### 阶段3：游戏引擎重构（预计3-4天）

#### 3.1 创建新的GameEngine（8小时）
**任务3.1.1**: 创建简化版GameEngine
- 在`lib/core/engine/`目录下创建`game_engine_new.dart`
- 实现只需要4个参数的构造函数
- 内部创建阶段处理器和工具类
- 实现initializeGame和executeGameStep方法

**任务3.1.2**: 创建GameRandom工具类
- 在`lib/core/engine/utils/`目录下创建`game_random.dart`
- 封装随机数生成逻辑
- 提供游戏相关的随机方法

**任务3.1.3**: 实现两阶段处理器
- 重构NightPhaseProcessor基于技能系统
- 重构DayPhaseProcessor基于技能系统，包含发言和投票逻辑
- 确认只有Night和Day两个阶段，投票作为 Day 阶段的一部分

**任务3.1.4**: 运行代码分析
```bash
dart analyze
```

#### 3.2 重构GameState（6小时）
**任务3.2.1**: 简化GameState
- 移除对NightActionState和VotingState的依赖
- 移除GameState中的status字段，由GameEngine使用GameEngineStatus管理
- 直接管理游戏状态
- 添加技能效果管理方法

**任务3.2.2**: 删除旧的状态管理类
- 删除`lib/core/state/night_action_state.dart`
- 删除`lib/core/state/voting_state.dart`
- 移除所有相关引用

**任务3.2.3**: 更新事件系统以支持技能
- 添加技能相关的事件类型
- 更新事件处理逻辑

**任务3.2.4**: 运行代码分析
```bash
dart analyze
```

#### 3.3 创建GameAssembler（4小时）
**任务3.3.1**: 创建GameAssembler类
- 在`lib/core/engine/`目录下创建`game_assembler.dart`
- 实现assembleGame静态方法
- 实现配置加载、场景选择、玩家创建逻辑

**任务3.3.2**: 实现玩家创建逻辑
- 实现根据场景配置创建玩家列表
- 实现角色分配逻辑
- 实现Driver配置逻辑

**任务3.3.3**: 运行代码分析
```bash
dart analyze
```

### 阶段4：清理旧架构（预计2-3天）

#### 4.1 删除旧的游戏引擎组件（6小时）
**任务4.1.1**: 删除旧的GameEngine
- 备份并删除旧的`game_engine.dart`
- 删除所有对旧GameEngine的引用

**任务4.1.2**: 删除GameParameters接口
- 删除`lib/core/engine/game_parameters.dart`
- 移除所有对GameParameters的引用

**任务4.1.3**: 删除不必要的服务类
- 删除`lib/core/services/action_resolver_service.dart`
- 删除`lib/core/services/event_filter_service.dart`
- 删除`lib/core/services/player_order_service.dart`

**任务4.1.4**: 运行代码分析
```bash
dart analyze
```

#### 4.2 清理过度设计的组件（4小时）
**任务4.2.1**: 删除Action相关类
- 删除所有Action相关的类和接口
- 移除所有对Action的引用

**任务4.2.2**: 重命名LLMService为PlayerDriver和GameStatus为GameEngineStatus
- 更新所有对LLMService的引用为PlayerDriver
- 更新所有对GameStatus的引用为GameEngineStatus
- 确保功能保持一致

**任务4.2.3**: 删除StreamController相关代码
- 简化事件分发机制
- 使用GameObserver替代

**任务4.2.4**: 运行代码分析
```bash
dart analyze
```

#### 4.3 更新依赖注入和适配器（4小时）
**任务4.3.1**: 更新DI配置
- 更新`lib/di.dart`中的依赖注入配置
- 注册新的GameEngine和相关组件

**任务4.3.2**: 更新GameService
- 更新`lib/services/game_service.dart`以使用新的GameEngine
- 保持Stream事件流的兼容性

**任务4.3.3**: 更新控制台适配器
- 更新`lib/widget/console/console_adapter.dart`
- 使用GameAssembler创建游戏

**任务4.3.4**: 运行代码分析
```bash
dart analyze
```

### 阶段5：测试和验证（预计2-3天）

#### 5.1 单元测试（8小时）
**任务5.1.1**: 为GameConfig编写测试
- 测试配置加载和验证逻辑
- 测试PlayerIntelligence功能

**任务5.1.2**: 为GameScenario编写测试
- 测试场景接口实现
- 测试角色分配逻辑

**任务5.1.3**: 为GamePlayer编写测试
- 测试AIPlayer和HumanPlayer功能
- 测试技能执行逻辑

**任务5.1.4**: 为技能系统编写测试
- 测试技能执行和冲突处理
- 测试优先级排序

**任务5.1.5**: 运行代码分析和测试
```bash
dart analyze
dart test
```

#### 5.2 集成测试（6小时）
**任务5.2.1**: 测试完整的游戏流程
- 测试游戏初始化
- 测试阶段转换
- 测试游戏结束条件

**任务5.2.2**: 测试不同场景配置
- 测试9人局
- 测试12人局
- 测试自定义场景

**任务5.2.3**: 测试PlayerDriver功能
- 测试AIPlayerDriver
- 测试HumanPlayerDriver（模拟）

**任务5.2.4**: 运行代码分析和测试
```bash
dart analyze
dart test
```

#### 5.3 性能测试（4小时）
**任务5.3.1**: 性能基准测试
- 测试游戏引擎性能
- 测试技能系统性能
- 测试事件系统性能

**任务5.3.2**: 内存使用测试
- 检查内存泄漏
- 优化内存使用

**任务5.3.3**: 运行代码分析和性能测试
```bash
dart analyze
dart test --coverage
```

### 阶段6：文档和部署（预计1-2天）

#### 6.1 更新文档（4小时）
**任务6.1.1**: 更新CLAUDE.md
- 更新架构描述
- 更新开发指南
- 添加新的API文档

**任务6.1.2**: 创建迁移指南
- 创建详细的迁移文档
- 提供代码示例
- 说明破坏性变更

**任务6.1.3**: 更新README
- 更新项目说明
- 更新使用指南

**任务6.1.4**: 运行代码分析
```bash
dart analyze
```

#### 6.2 最终验证（2小时）
**任务6.2.1**: 完整的代码分析
```bash
dart analyze --fatal-infos
```

**任务6.2.2**: 完整的测试套件
```bash
dart test --coverage
```

**任务6.2.3**: Flutter应用测试
```bash
flutter analyze
flutter test
```

## 风险缓解措施

### 功能风险
- **风险**: 可能丢失某些功能
- **缓解**: 仔细分析现有功能，确保必要功能不丢失
- **检查点**: 每个阶段结束后进行功能验证

### 性能风险
- **风险**: 重构可能影响性能
- **缓解**: 性能测试对比，确保性能不下降
- **检查点**: 阶段5进行专门的性能测试

## 成功标准

### 代码质量标准
- `dart analyze` 无错误和警告
- 测试覆盖率达到80%以上
- 代码符合项目编码规范

### 功能标准
- 所有新架构功能正常工作
- 新架构支持所有游戏场景
- AI玩家决策质量不下降
- 两阶段游戏流程运行正常（Night/Day）

### 性能标准
- 游戏运行性能不低于现有版本
- 内存使用量不增加
- 启动时间不延长

## 时间估算总结

- **阶段1**: 2-3天（基础设施和核心接口）
- **阶段2**: 3-4天（实体重构）
- **阶段3**: 3-4天（游戏引擎重构）
- **阶段4**: 2-3天（清理旧架构）
- **阶段5**: 2-3天（测试和验证）
- **阶段6**: 1-2天（文档和部署）

**总计**: 13-19天

## 注意事项

1. **渐进式重构**: 每个阶段都要确保代码可以正常运行
2. **频繁测试**: 每个任务完成后都要运行`dart analyze`
3. **备份重要**: 在删除旧代码前确保新代码完全可用
4. **文档同步**: 及时更新文档，保持文档和代码的一致性
5. **团队沟通**: 如果是团队开发，确保团队成员了解重构进度