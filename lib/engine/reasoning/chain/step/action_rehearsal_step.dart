import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/game_logger.dart';
import 'package:werewolf_arena/engine/reasoning/memory/working_memory.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';
import 'package:werewolf_arena/engine/reasoning/chain/step/reasoning_step.dart';
import 'package:werewolf_arena/engine/skill/conspire_skill.dart';

/// 行动预演与风险评估步骤
///
/// CoT推理链的质量门控步骤：在发言输出前进行预审查
/// 检查策略一致性、信息安全、面具一致性
/// 如果发现严重问题，标记需要重新生成
///
/// **特殊情况处理**:
/// - 狼人夜间讨论(ConspireSkill)：允许提及队友、使用"我们"等
/// - 其他公开场合：严格禁止泄露秘密信息
class ActionRehearsalStep extends ReasoningStep {
  final String modelId;

  /// 最大重试次数（仅用于LLM调用，不是重新生成次数）
  @override
  int get maxRetries => 3;

  ActionRehearsalStep({required this.modelId});

  @override
  String get name => 'action_rehearsal';

  @override
  String get description => '预演行动并评估风险';

  @override
  bool shouldSkip(ReasoningContext context) {
    // 如果没有生成发言，跳过此步骤
    final message = context.getStepOutput<String>('speech_generation');
    return message == null || message.isEmpty;
  }

  @override
  Future<ReasoningContext> execute(
    ReasoningContext context,
    OpenAIClient client,
  ) async {
    GameLogger.instance.d('[行动预演] 开始审查...');

    // *** 新增：检查是否是狼人夜间讨论 ***
    final isWerewolfConspire = context.skill is ConspireSkill;

    // 如果是狼人夜间讨论，跳过信息安全检查（可以提及队友）
    if (isWerewolfConspire) {
      GameLogger.instance.d('[行动预演] 狼人夜间讨论，跳过信息安全审查');
      context.setStepOutput('action_rehearsal_result', {
        'passed': true,
        'issues': [],
        'severity': 'none',
        'skipped_reason': '狼人夜间讨论可以自由交流',
      });
      context.setStepOutput('needs_regeneration', false);
      return context;
    }

    // 获取生成的发言和相关上下文
    final message = context.getStepOutput<String>('speech_generation');
    final targetPlayer = context.getStepOutput<String>('target_player');
    final strategy = context.getStepOutput<Map<String, dynamic>>('strategy');
    final selectedMask = context.getStepOutput('selected_mask');
    final workingMemory = context.getStepOutput<WorkingMemory>(
      'working_memory',
    );

    // 构建Prompt
    final systemPrompt = _buildSystemPrompt();
    final userPrompt = _buildUserPrompt(
      context,
      message!,
      targetPlayer,
      strategy,
      selectedMask,
      workingMemory,
    );

    // 调用LLM进行审查
    try {
      final response = await request(
        client: client,
        modelId: modelId,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        context: context,
      );

      // 解析响应
      final passed = _parseBool(response['passed']) ?? true;
      final issues = response['issues'] as List? ?? [];
      final severity = response['severity'] as String? ?? 'low';
      final recommendation = response['recommendation'] as String?;

      // 记录审查结果
      final rehearsalResult = {
        'passed': passed,
        'issues': issues,
        'severity': severity,
        'recommendation': recommendation,
      };

      context.setStepOutput('action_rehearsal_result', rehearsalResult);

      // 记录到思考链
      final thought = StringBuffer();
      thought.writeln('[步骤: 行动预演]');
      thought.writeln();

      if (passed) {
        GameLogger.instance.d('[行动预演] 通过审查');
        thought.writeln('审查结果: ✓ 通过');
        context.setStepOutput('needs_regeneration', false);
      } else {
        GameLogger.instance.w(
          '[行动预演] 未通过审查 - 严重程度: $severity, '
          '问题: ${issues.join(", ")}',
        );
        thought.writeln('审查结果: ✗ 未通过');
        thought.writeln('严重程度: $severity');
        thought.writeln();
        thought.writeln('发现的问题:');
        for (var i = 0; i < issues.length; i++) {
          thought.writeln('${i + 1}. ${issues[i]}');
        }

        if (recommendation != null) {
          thought.writeln();
          thought.writeln('建议: $recommendation');
        }

        // 标记需要重新生成（由推理引擎处理）
        context.setStepOutput('needs_regeneration', true);
      }

      context.appendThought(thought.toString());
    } catch (e) {
      GameLogger.instance.e('[行动预演] 失败: $e');
      // 降级：如果审查失败，默认通过（避免阻塞游戏流程）
      context.setStepOutput('action_rehearsal_result', {
        'passed': true,
        'issues': [],
        'severity': 'none',
      });
      context.setStepOutput('needs_regeneration', false);
    }

    return context;
  }

  /// 构建System Prompt
  String _buildSystemPrompt() {
    return '''
你是狼人杀行动审查专家。在玩家执行行动前，评估其安全性和有效性。

**重要**: 本审查仅针对**公开场合的发言**（白天讨论、投票、遗言等）。
狼人夜间讨论已被自动跳过，因为狼队内部可以自由交流。

**审查维度（按优先级）**:

1. **信息安全检查** (最高优先级)
   - 是否泄露真实身份、队友信息、夜间行动结果（除非该角色应公开）
   - 是否使用了只有特定角色才知道的信息
   - 示例泄露：
     * 狼人在**白天**说"兄弟们"、"我们"、"队友" (❌ 严重泄露)
     * 守卫暗示守护对象
     * 预言家不该公开时说查验结果

2. **策略一致性检查**
   - 发言/行动是否符合制定的策略目标
   - 目标玩家选择是否合理
   - 示例不一致：策略是"低调观察"但发言激进攻击他人

3. **面具一致性检查**
   - 发言风格是否符合选择的角色面具（如果有）
   - 语气、用词、态度是否匹配
   - 示例不一致：选择"冷静分析者"面具但发言情绪化

**严重程度分级**:
- critical: 严重信息泄露，必须重新生成
- high: 明显策略矛盾，强烈建议重新生成
- medium: 轻微不一致，可以接受但有改进空间
- low: 微小问题，可以忽略

**输出**: 审查是否通过 + 问题列表 + 严重程度 + 改进建议
''';
  }

  /// 构建User Prompt
  String _buildUserPrompt(
    ReasoningContext context,
    String message,
    String? targetPlayer,
    Map<String, dynamic>? strategy,
    dynamic selectedMask,
    WorkingMemory? memory,
  ) {
    final player = context.player;
    final state = context.state;

    // 构建策略信息
    final strategyInfo = strategy != null
        ? '''
**制定的策略**
目标: ${strategy['goal'] ?? '未知'}
计划: ${strategy['main_plan'] ?? '未知'}
${strategy['target'] != null ? '目标玩家: ${strategy['target']}' : ''}
'''
        : '(无策略信息)';

    // 构建面具信息
    final maskInfo = selectedMask != null
        ? '\n**选择的面具**: ${selectedMask.toString()}'
        : '';

    // 构建秘密信息（用于检查泄露）
    final secretInfo = memory != null
        ? memory.secretKnowledge.toText()
        : '';

    return '''
**待审查的行动**

玩家: ${player.name} (${player.role.name})
回合: 第${state.day}天

**发言内容**:
$message

${targetPlayer != null ? '**目标玩家**: $targetPlayer' : ''}

$strategyInfo$maskInfo

**秘密信息** (仅用于泄露检测，不应在发言中出现)
$secretInfo

---

**任务**: 审查以上行动，检查是否存在问题。

返回JSON:
```json
{
  "passed": true/false,
  "issues": ["问题1", "问题2"],
  "severity": "critical/high/medium/low",
  "recommendation": "如果未通过，给出具体改进建议"
}
```

**Few-Shot示例**:

示例1 - 严重泄露 (狼人暴露队友):
```json
{
  "passed": false,
  "issues": [
    "发言中使用'兄弟们'直接暴露狼队关系",
    "提到'我们一起'泄露了团队协作信息"
  ],
  "severity": "critical",
  "recommendation": "移除所有暗示队友关系的词汇，改为单独个体的视角发言"
}
```

示例2 - 策略不一致:
```json
{
  "passed": false,
  "issues": [
    "策略是'低调观察'但发言过于激进",
    "目标玩家与策略中指定的不同"
  ],
  "severity": "high",
  "recommendation": "调整发言语气为中立观察，聚焦策略指定的目标玩家"
}
```

示例3 - 通过审查:
```json
{
  "passed": true,
  "issues": [],
  "severity": "low",
  "recommendation": null
}
```

示例4 - 轻微问题但可接受:
```json
{
  "passed": true,
  "issues": ["发言稍显机械，人情味不足"],
  "severity": "low",
  "recommendation": "可以添加更自然的语气词"
}
```

**注意**:
- "声称"某个身份是策略行为（如狼人悍跳预言家），不算泄露
- 基于公开信息的推理不算泄露
- 只有暴露"只有自己知道的秘密信息"才算泄露
''';
  }

  /// 健壮的bool解析
  bool? _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
    }
    return null;
  }
}
