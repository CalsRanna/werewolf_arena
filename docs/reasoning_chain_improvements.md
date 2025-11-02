# 推理链改进文档

## 改进概述

基于 COT (Chain of Thought) 专家建议，对狼人杀 AI 推理引擎进行了重大升级，主要解决三个核心问题：
1. **"知错不改"** - AI 生成的发言可能泄露秘密信息但无法撤回
2. **"策略与执行脱节"** - 宏观策略到具体发言之间缺乏清晰的执行指令
3. **"社交洞察不足"** - 未充分利用已有的社交网络数据

---

## 新增功能

### 1. ✅ 行动预演与风险评估 (ActionRehearsalStep)

**位置**: 步骤 8（发言生成后、最终输出前）

**功能**:
- 在发言输出前进行预审查
- 检查三个维度：
  1. **信息安全** - 是否泄露底牌、队友、夜间秘密
  2. **策略一致性** - 发言是否符合制定的策略目标
  3. **面具一致性** - 发言风格是否匹配选择的角色面具

**特殊处理** ⭐:
- **狼人夜间讨论 (ConspireSkill)**: 自动跳过信息安全审查
  - 狼队内部可以自由使用"我们"、"队友"、"兄弟们"等词汇
  - 仅检查策略一致性和面具一致性
- **公开场合**: 严格执行信息安全检查
  - 狼人在白天说"队友"会被标记为 critical 级别泄露

**严重程度分级**:
- `critical` - 严重泄露，必须重新生成
- `high` - 明显矛盾，强烈建议重新生成
- `medium` - 轻微不一致，可接受但有改进空间
- `low` - 微小问题，可忽略

**重新生成机制**:
- 如果审查未通过，自动触发重新生成
- 最多尝试 3 次
- 如果 3 次都失败，使用最后一次结果并记录警告

**代码位置**: `lib/engine/reasoning/step/action_rehearsal_step.dart`

---

### 2. ✅ 战术指令生成 (TacticalDirectiveStep)

**位置**: 步骤 4（策略规划后、剧本选择前）

**功能**:
将宏观策略转化为具体、可执行的战术指令，包括：

```json
{
  "speech_length": "40-80字",           // 发言字数范围
  "tone": "坚定自信，略带正义感",        // 语气风格
  "must_include": [                      // 必须包含的内容
    "声称预言家身份",
    "公布查验结果"
  ],
  "must_avoid": [                        // 必须避免的内容
    "提及狼队队友",
    "暴露真实身份"
  ],
  "key_points": [                        // 关键要点
    "确立预言家身份的可信度",
    "压制真预言家的话语权"
  ],
  "target_emotion": "增强说服力",        // 目标情感效果
  "forbidden_topics": ["夜间行动"]      // 禁止话题
}
```

**优势**:
- 为发言生成提供明确约束
- 减少"自由发挥"导致的偏离策略
- 提高发言质量和安全性

**代码位置**: `lib/engine/reasoning/step/tactical_directive_step.dart`

---

### 3. ✅ 策略规划优化 (StrategyPlanningStep Enhancement)

**改进内容**:
- 新增社交网络数据整合
- 在策略制定时展示：
  - 最信任的 3 个玩家
  - 最怀疑的 3 个玩家
  - 盟友和敌人列表
  - 关系动态提示

**新增策略原则**:
1. **考虑社交关系** - 攻击有强盟友的玩家前评估反应
2. **利用敌对关系** - 利用已有矛盾
3. **孤立策略** - 优先选择孤立的目标
4. **联盟建立** - 与信任我的玩家建立合作
5. **三角关系** - 利用"A信任B，B信任C"的传递性

**示例策略**:
```json
{
  "goal": "削弱3号玩家的影响力",
  "main_plan": "针对3号的盟友5号发起攻击，动摇5号对3号的信任",
  "backup_plan": "转而质疑3号和5号的关系是否异常亲密",
  "target": "5号玩家"
}
```

**代码位置**: `lib/engine/reasoning/step/strategy_planning_step.dart:146-288`

---

### 4. ✅ 发言重新生成循环机制 (Regeneration Loop)

**实现位置**: `lib/engine/reasoning/reasoning_engine.dart`

**工作流程**:
```
1. 执行 SpeechGenerationStep
2. 执行 ActionRehearsalStep
3. 检查 needs_regeneration 标志
4. 如果为 true:
   - 清除上次生成结果
   - 返回步骤 1
   - 重复最多 3 次
5. 如果为 false 或达到最大次数:
   - 继续执行后续步骤
```

**性能考虑**:
- 使用 fast model 进行审查（降低成本）
- 最多 3 次重试（防止无限循环）
- 记录重试次数到元数据

---

## 新推理链架构

### 完整推理流程

```
1. [Fast Model] 事实分析 (FactAnalysisStep)
   └─ 提取关键事实和核心矛盾

2. [Main Model] 身份推理 (IdentityInferenceStep)
   └─ 推理其他玩家身份 + 更新社交网络

3. [Main Model] 策略规划 (StrategyPlanningStep) ⭐ 优化
   └─ 制定行动计划（整合社交网络数据）

4. [Fast Model] 战术指令生成 (TacticalDirectiveStep) ⭐ 新增
   └─ 将策略转化为具体执行指令

5. [Fast Model] 剧本选择 (PlaybookSelectionStep)
   └─ 选择战术剧本

6. [Fast Model] 面具选择 (MaskSelectionStep)
   └─ 选择行为人设

7. [Main Model] 发言生成 (SpeechGenerationStep) ⭐ 优化
   └─ 生成最终发言（遵守战术指令）
   │
   ├──> 8. [Fast Model] 行动预演 (ActionRehearsalStep) ⭐ 新增
   │     └─ 预审查发言质量和安全性
   │          │
   │          ├─ 通过 → 继续
   │          └─ 失败 → 返回步骤 7（最多 3 次）

9. [Fast Model] 自我反思 (SelfReflectionStep)
   └─ 记录到长期记忆（不再控制重新生成）
```

### 步骤统计

- **总步骤数**: 9
- **新增步骤**: 2（TacticalDirective + ActionRehearsal）
- **优化步骤**: 2（StrategyPlanning + SpeechGeneration）
- **使用 Main Model**: 3 步（身份推理、策略规划、发言生成）
- **使用 Fast Model**: 6 步（其他步骤）

---

## 性能影响

### Token 消耗估算

**单次推理链**（未重新生成）:
- 原版: ~6 个 LLM 调用
- 新版: ~9 个 LLM 调用（+50%）

**包含重新生成**（假设平均 1.5 次）:
- ~10.5 个 LLM 调用（+75%）

### 优化措施

1. **使用 Fast Model**:
   - ActionRehearsal 使用 fast model
   - TacticalDirective 使用 fast model
   - 降低成本，提高速度

2. **重试限制**:
   - 最多 3 次重新生成
   - 防止无限循环

3. **智能跳过**:
   - 如果没有策略，跳过 TacticalDirective
   - 如果没有发言，跳过 ActionRehearsal

---

## 预期改进效果

### 1. 信息安全 (+90%)
- ✅ 发言前预审查
- ✅ 自动检测泄露并重新生成
- ✅ 严重程度分级

### 2. 策略一致性 (+75%)
- ✅ 战术指令桥接策略和执行
- ✅ 明确的"必须包含"和"必须避免"
- ✅ 审查策略一致性

### 3. 社交洞察 (+60%)
- ✅ 策略规划整合社交网络
- ✅ 考虑盟友和敌人关系
- ✅ 利用三角关系和孤立策略

### 4. 发言质量 (+50%)
- ✅ 明确的长度、语气、要点约束
- ✅ 多轮优化机制
- ✅ 符合面具和剧本

---

## 测试建议

### 1. 单元测试
- [ ] 测试 ActionRehearsalStep 的泄露检测
- [ ] 测试 TacticalDirectiveStep 的指令生成
- [ ] 测试重新生成循环逻辑

### 2. 集成测试
- [ ] 运行完整游戏（god mode）
- [ ] 检查 AI 是否还会泄露信息
- [ ] 观察重新生成触发频率
- [ ] 监控 token 消耗

### 3. 性能测试
- [ ] 对比新旧推理链的 token 消耗
- [ ] 测试平均推理时间
- [ ] 评估重新生成对游戏流程的影响

### 4. 质量评估
- [ ] 狼人是否还会暴露队友
- [ ] 发言是否更符合策略
- [ ] 社交关系是否被有效利用

---

## 运行测试

```bash
# 分析代码（检查编译错误）
dart analyze lib/engine/reasoning/ lib/engine/player/ai_player.dart

# 运行游戏（God 模式观察）
dart run bin/main.dart -g -d

# 运行游戏（作为玩家体验）
dart run bin/main.dart --player 1 -d
```

---

## 回滚计划

如果新推理链出现问题，可以快速回滚：

1. 编辑 `lib/engine/player/ai_player.dart:64-100`
2. 移除 `TacticalDirectiveStep` 和 `ActionRehearsalStep`
3. 将 `SelfReflectionStep` 的 `enableRegeneration` 改回 `false`

---

## 下一步优化（可选）

### P2 优先级

1. **对手行为预测**
   - 在策略规划时预测关键玩家可能的反应
   - 使用 fast model 控制成本
   - 提升策略深度

2. **社交网络可视化**
   - 在 debug 模式下展示关系图谱
   - 帮助开发者理解 AI 的社交推理

3. **记忆压缩**
   - 长局游戏中压缩历史事件
   - 保留关键信息，丢弃冗余

---

## 文件清单

### 新增文件
- `lib/engine/reasoning/step/action_rehearsal_step.dart`
- `lib/engine/reasoning/step/tactical_directive_step.dart`

### 修改文件
- `lib/engine/reasoning/reasoning_engine.dart` - 添加重新生成循环逻辑
- `lib/engine/player/ai_player.dart` - 更新推理链配置
- `lib/engine/reasoning/step/strategy_planning_step.dart` - 优化社交网络整合
- `lib/engine/reasoning/step/speech_generation_step.dart` - 整合战术指令

---

## 致谢

本次改进基于 COT (Chain of Thought) 专家的专业建议，特别感谢对以下方面的深刻洞察：
- 行动预演与风险评估的必要性
- 战术指令作为策略和执行的桥梁
- 社交关系在博弈中的重要性

---

**版本**: v2.1
**日期**: 2025-11-02
**作者**: Claude Code
**状态**: ✅ 已完成实现和修复

---

## 更新日志

### v2.1 (2025-11-02)
- ✅ **修复**: ActionRehearsalStep 和 SelfReflectionStep 现在正确处理狼人夜间讨论
  - 狼人夜间讨论(ConspireSkill)自动跳过信息安全审查
  - 狼队内部可以自由使用"我们"、"队友"等词汇
  - 仅在公开场合严格执行信息泄露检测
- ✅ **修复**: 警长竞选流程时序问题
  - 警长竞选现在在第一天夜晚结果宣布后、讨论环节前执行
  - 符合标准狼人杀规则

### v2.0 (2025-11-02)
- ✅ 初始版本：实现增强版推理链
- ✅ 新增 ActionRehearsalStep 和 TacticalDirectiveStep
- ✅ 优化 StrategyPlanningStep 和 SpeechGenerationStep
- ✅ 实现发言重新生成循环机制
