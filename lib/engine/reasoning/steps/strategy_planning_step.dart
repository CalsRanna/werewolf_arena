import 'dart:convert';

import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/memory/social_analyzer.dart';
import 'package:werewolf_arena/engine/memory/working_memory.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_step.dart';

/// 策略规划步骤
///
/// CoT推理链的第三步：基于身份推理结果，制定本轮行动计划
/// 输出：行动目标、主要计划、备用计划、风险评估、应对措施
class StrategyPlanningStep extends ReasoningStep {
  final String modelId;

  StrategyPlanningStep({required this.modelId});

  @override
  String get name => 'strategy_planning';

  @override
  String get description => '制定本轮行动策略';

  @override
  Future<ReasoningContext> execute(
    ReasoningContext context,
    OpenAIClient client,
  ) async {
    GameEngineLogger.instance.d('[策略规划] 开始规划...');

    // 1. 获取前面步骤的分析结果
    final coreConflict = context.getStepOutput<String>('core_conflict') ?? '无';
    final keyFacts = context.getStepOutput<List<KeyFact>>('key_facts') ?? [];
    final workingMemory = context.getStepOutput<WorkingMemory>('working_memory');

    // 2. 构建Prompt
    final systemPrompt = _buildSystemPrompt();
    final userPrompt = _buildUserPrompt(
      context,
      coreConflict,
      keyFacts,
      workingMemory,
    );

    // 3. 调用LLM
    try {
      final response = await callLLMWithRetry(
        client: client,
        modelId: modelId,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        context: context,
      );

      // 4. 解析响应
      final strategy = _parseResponse(response);

      // 5. 存入上下文
      context.setStepOutput('strategy', strategy);

      // 6. 更新社交网络（基于策略计划）
      final workingMemory = context.getStepOutput<WorkingMemory>('working_memory');
      if (workingMemory != null && workingMemory.socialNetwork != null) {
        final updatedNetwork = SocialAnalyzer.updateFromStrategy(
          currentNetwork: workingMemory.socialNetwork!,
          strategy: strategy,
          state: context.state,
        );
        workingMemory.updateSocialNetwork(updatedNetwork);
        context.setStepOutput('working_memory', workingMemory);
      }

      // 7. 记录到思考链
      final thought = StringBuffer();
      thought.writeln('[步骤3: 策略规划]');
      thought.writeln();
      thought.writeln('目标: ${strategy['goal']}');
      thought.writeln();
      thought.writeln('主要计划:');
      thought.writeln(strategy['main_plan']);
      if (strategy['backup_plan'] != null) {
        thought.writeln();
        thought.writeln('备用计划:');
        thought.writeln(strategy['backup_plan']);
      }
      if (strategy['target'] != null) {
        thought.writeln();
        thought.writeln('目标玩家: ${strategy['target']}');
      }

      context.appendThought(thought.toString());

      GameEngineLogger.instance.d(
        '[策略规划] 完成 - 目标: ${strategy['goal']}',
      );
    } catch (e) {
      GameEngineLogger.instance.e('[策略规划] 失败: $e');
    }

    return context;
  }

  /// 构建System Prompt
  String _buildSystemPrompt() {
    return '''
你是狼人杀策略规划专家。基于局势和身份推理，制定本轮行动策略。

规划要点：目标明确、准备备选方案、评估风险、服务阵营胜利。

输出：行动目标 + 主要计划 + 备用计划 + 目标玩家 + 风险 + 应对措施
''';
  }

  /// 构建User Prompt
  String _buildUserPrompt(
    ReasoningContext context,
    String coreConflict,
    List<KeyFact> keyFacts,
    WorkingMemory? memory,
  ) {
    final player = context.player;
    final state = context.state;
    final skill = context.skill;

    // 获取身份推测
    final identityEstimates = memory?.identityEstimates ?? {};
    final identitySummary = StringBuffer();
    if (identityEstimates.isNotEmpty) {
      identityEstimates.forEach((playerName, estimate) {
        identitySummary.writeln(
          '- $playerName: ${estimate.estimatedRole} (${estimate.confidence}%)',
        );
      });
    } else {
      identitySummary.writeln('暂无身份推测');
    }

    return '''
**我的信息**
我是${player.name}，角色：${player.role.name}，阵营：${player.role.id == 'werewolf' ? '狼人' : '好人'}
${memory?.secretKnowledge.toText() ?? ''}

**局势** (第${state.day}天，${skill.name})
核心矛盾：$coreConflict

**关键事实**
${keyFacts.isEmpty ? '暂无' : keyFacts.asMap().entries.map((e) => '${e.key + 1}. ${e.value.description}').join('\n')}

**身份推测**
$identitySummary

---

输出JSON：
```json
{
  "goal": "核心目标(1句话)",
  "main_plan": "主要计划步骤",
  "backup_plan": "备选方案(可选)",
  "target": "目标玩家名(可选)",
  "risks": ["风险1", "风险2"],
  "countermeasures": ["应对1", "应对2"]
}
```

**Few-Shot示例**:

场景1 - 好人预言家起跳:
```json
{
  "goal": "说服好人相信我是真预言家",
  "main_plan": "强势公布查验结果，给出警徽流，攻击对方逻辑漏洞",
  "backup_plan": "如被质疑，展示更详细推理过程",
  "target": "2号玩家",
  "risks": ["对方预言家发言质量高"],
  "countermeasures": ["强调自己验人准确率"]
}
```

场景2 - 狼人低调观察:
```json
{
  "goal": "保持低调，收集信息，避免成为众矢之的",
  "main_plan": "发言时保持中立态度，不过度表态，记录其他玩家的矛盾点",
  "backup_plan": "如被怀疑，用逻辑分析其他可疑玩家转移视线",
  "target": null,
  "risks": ["过度沉默可能被怀疑", "队友暴露导致连累"],
  "countermeasures": ["适度发言展示思考", "保持与暴露队友的距离"]
}
```

场景3 - 村民推理身份:
```json
{
  "goal": "找出狼人，保护神牌",
  "main_plan": "分析发言逻辑漏洞，找出矛盾点，引导投票方向",
  "target": "5号玩家",
  "risks": ["可能误判好人"],
  "countermeasures": ["保持开放心态，听取反驳"]
}
```
''';
  }

  /// 解析LLM响应
  Map<String, dynamic> _parseResponse(String response) {
    try {
      // 提取JSON（去除markdown代码块）
      String jsonStr = response.trim();
      if (jsonStr.contains('```json')) {
        final start = jsonStr.indexOf('```json') + 7;
        final end = jsonStr.lastIndexOf('```');
        jsonStr = jsonStr.substring(start, end).trim();
      } else if (jsonStr.contains('```')) {
        final start = jsonStr.indexOf('```') + 3;
        final end = jsonStr.lastIndexOf('```');
        jsonStr = jsonStr.substring(start, end).trim();
      }

      // 解析JSON
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      return {
        'goal': json['goal'] as String? ?? '保持观察',
        'main_plan': json['main_plan'] as String? ?? '暂无计划',
        'backup_plan': json['backup_plan'] as String?,
        'target': json['target'] as String?,
        'risks': json['risks'] as List? ?? [],
        'countermeasures': json['countermeasures'] as List? ?? [],
      };
    } catch (e) {
      GameEngineLogger.instance.e(
        '[策略规划] JSON解析失败: $e\nResponse: $response',
      );
      return {
        'goal': '保持观察',
        'main_plan': '暂无计划',
      };
    }
  }
}
