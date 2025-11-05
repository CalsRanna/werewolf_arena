import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/game_logger.dart';
import 'package:werewolf_arena/engine/reasoning/memory/working_memory.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';
import 'package:werewolf_arena/engine/reasoning/chain/step/reasoning_step.dart';

/// 战术指令生成步骤
///
/// 将宏观策略转化为具体的、可执行的战术指令
/// 为发言生成步骤提供明确的约束和指导
class TacticalDirectiveStep extends ReasoningStep {
  final String modelId;

  TacticalDirectiveStep({required this.modelId});

  @override
  String get name => 'tactical_directive';

  @override
  String get description => '将策略转化为具体执行指令';

  @override
  bool shouldSkip(ReasoningContext context) {
    // 如果没有策略，跳过此步骤
    final strategy = context.getStepOutput<Map<String, dynamic>>('strategy');
    return strategy == null;
  }

  @override
  Future<ReasoningContext> execute(
    ReasoningContext context,
    OpenAIClient client,
  ) async {
    GameLogger.instance.d('[战术指令] 开始生成...');

    // 获取策略规划结果
    final strategy = context.getStepOutput<Map<String, dynamic>>('strategy')!;
    final workingMemory = context.getStepOutput<WorkingMemory>(
      'working_memory',
    );
    final selectedPlaybook = context.getStepOutput('selected_playbook');
    final selectedMask = context.getStepOutput('selected_mask');

    // 构建Prompt
    final systemPrompt = _buildSystemPrompt();
    final userPrompt = _buildUserPrompt(
      context,
      strategy,
      workingMemory,
      selectedPlaybook,
      selectedMask,
    );

    // 调用LLM
    try {
      final response = await request(
        client: client,
        modelId: modelId,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        context: context,
      );

      // 解析响应
      final directive = {
        'speech_length': response['speech_length'] as String? ?? '40-80字',
        'tone': response['tone'] as String? ?? '自然',
        'must_include': response['must_include'] as List? ?? [],
        'must_avoid': response['must_avoid'] as List? ?? [],
        'target_emotion': response['target_emotion'] as String?,
        'key_points': response['key_points'] as List? ?? [],
        'forbidden_topics': response['forbidden_topics'] as List? ?? [],
      };

      // 存入上下文
      context.setStepOutput('tactical_directive', directive);

      // 记录到思考链
      final thought = StringBuffer();
      thought.writeln('[步骤: 战术指令]');
      thought.writeln();
      thought.writeln('发言长度: ${directive['speech_length']}');
      thought.writeln('语气风格: ${directive['tone']}');

      if ((directive['must_include'] as List).isNotEmpty) {
        thought.writeln();
        thought.writeln('必须包含:');
        for (var i = 0; i < (directive['must_include'] as List).length; i++) {
          thought.writeln(
            '${i + 1}. ${(directive['must_include'] as List)[i]}',
          );
        }
      }

      if ((directive['must_avoid'] as List).isNotEmpty) {
        thought.writeln();
        thought.writeln('必须避免:');
        for (var i = 0; i < (directive['must_avoid'] as List).length; i++) {
          thought.writeln('${i + 1}. ${(directive['must_avoid'] as List)[i]}');
        }
      }

      if ((directive['key_points'] as List).isNotEmpty) {
        thought.writeln();
        thought.writeln('关键要点:');
        for (var i = 0; i < (directive['key_points'] as List).length; i++) {
          thought.writeln('${i + 1}. ${(directive['key_points'] as List)[i]}');
        }
      }

      if (directive['target_emotion'] != null) {
        thought.writeln();
        thought.writeln('目标情感: ${directive['target_emotion']}');
      }

      context.appendThought(thought.toString());

      GameLogger.instance.d(
        '[战术指令] 完成 - 语气: ${directive['tone']}, '
        '要点: ${(directive['key_points'] as List).length}个',
      );
    } catch (e) {
      GameLogger.instance.e('[战术指令] 失败: $e');
      // 降级：使用基础指令
      context.setStepOutput('tactical_directive', {
        'speech_length': '40-80字',
        'tone': '自然真诚',
        'must_include': [],
        'must_avoid': ['泄露底牌', '暴露队友'],
        'key_points': [strategy['goal']],
      });
    }

    return context;
  }

  /// 构建System Prompt
  String _buildSystemPrompt() {
    return '''
你是狼人杀战术指令专家。将宏观策略转化为具体的、可执行的指令。

**核心任务**: 为AI发言生成提供清晰、具体的约束和指导

**指令要素**:

1. **发言长度**: 指定字数范围（如"40-80字"、"80-120字"）
   - 简短精炼：投票、夜间行动等快节奏环节
   - 中等长度：讨论阶段的常规发言
   - 较长详细：重要陈述（如预言家起跳、猎人遗言）

2. **语气风格**: 描述说话方式和态度
   - 自信坚定、委婉试探、激动愤怒、冷静分析、困惑迷茫等
   - 需与选择的面具一致

3. **必须包含**: 发言中必须提到的关键内容
   - 具体事实、推理结论、表态立场等
   - 示例：["质疑3号玩家的验人结果", "表明支持5号"]

4. **必须避免**: 绝对不能提及的内容
   - 默认包含：泄露底牌、暴露队友、夜间秘密信息
   - 根据策略添加：避免过早暴露身份、避免与某玩家对立等

5. **关键要点**: 发言要传达的2-4个核心观点
   - 每个要点1句话概括

6. **目标情感** (可选): 希望引发的情感反应
   - 示例：增强说服力、制造紧张感、缓和气氛等

7. **禁止话题** (可选): 不应讨论的话题领域

**输出**: 结构化的战术指令JSON
''';
  }

  /// 构建User Prompt
  String _buildUserPrompt(
    ReasoningContext context,
    Map<String, dynamic> strategy,
    WorkingMemory? memory,
    dynamic selectedPlaybook,
    dynamic selectedMask,
  ) {
    final player = context.player;
    final state = context.state;
    final skill = context.skill;

    // 构建面具信息
    final maskInfo = selectedMask != null
        ? '\n选择的面具: ${selectedMask.toString()}'
        : '';

    // 构建剧本信息
    final playbookInfo = selectedPlaybook != null
        ? '\n选择的剧本: ${selectedPlaybook.toString()}'
        : '';

    return '''
**当前情境**

玩家: ${player.name} (${player.role.name})
回合: 第${state.day}天
当前技能: ${skill.name}

**宏观策略**
目标: ${strategy['goal'] ?? '未知'}
主要计划: ${strategy['main_plan'] ?? '未知'}
${strategy['backup_plan'] != null ? '备用方案: ${strategy['backup_plan']}' : ''}
${strategy['target'] != null ? '目标玩家: ${strategy['target']}' : ''}$maskInfo$playbookInfo

**秘密信息** (用于设置约束)
${memory?.secretKnowledge.toText() ?? '无'}

---

**任务**: 将以上宏观策略转化为具体的战术指令。

返回JSON:
```json
{
  "speech_length": "字数范围",
  "tone": "语气描述",
  "must_include": ["必须包含的内容1", "内容2"],
  "must_avoid": ["必须避免的内容1", "内容2"],
  "key_points": ["关键要点1", "要点2", "要点3"],
  "target_emotion": "目标情感效果(可选)",
  "forbidden_topics": ["禁止话题(可选)"]
}
```

**Few-Shot示例**:

场景1 - 狼人悍跳预言家:
```json
{
  "speech_length": "80-120字",
  "tone": "坚定自信，略带正义感",
  "must_include": [
    "声称预言家身份",
    "公布昨晚查验结果",
    "给出警徽流",
    "攻击真预言家的逻辑漏洞"
  ],
  "must_avoid": [
    "提及狼队队友",
    "暴露真实身份",
    "过度情绪化显得心虚"
  ],
  "key_points": [
    "确立预言家身份的可信度",
    "压制真预言家的话语权",
    "争取好人阵营的信任"
  ],
  "target_emotion": "增强说服力，让好人相信",
  "forbidden_topics": ["夜间狼队讨论内容"]
}
```

场景2 - 村民低调分析:
```json
{
  "speech_length": "40-70字",
  "tone": "冷静客观，谨慎试探",
  "must_include": [
    "基于公开信息的推理",
    "对某个可疑玩家的质疑"
  ],
  "must_avoid": [
    "过度激进导致被怀疑",
    "轻易站队表态"
  ],
  "key_points": [
    "展示逻辑思考能力",
    "保持中立观察者姿态"
  ],
  "target_emotion": null
}
```

场景3 - 预言家起跳:
```json
{
  "speech_length": "100-150字",
  "tone": "严肃认真，充满使命感",
  "must_include": [
    "起跳预言家",
    "公布所有查验记录",
    "详细警徽流",
    "呼吁好人保护和配合"
  ],
  "must_avoid": [
    "泄露其他神牌位置",
    "过于情绪化"
  ],
  "key_points": [
    "建立预言家公信力",
    "提供关键身份信息",
    "引导场上投票方向",
    "请求女巫守卫保护"
  ],
  "target_emotion": "赢得信任，增强阵营凝聚力"
}
```

场景4 - 狼人低调隐藏:
```json
{
  "speech_length": "30-50字",
  "tone": "普通平和，略显困惑",
  "must_include": [
    "简单表态支持某个预言家"
  ],
  "must_avoid": [
    "提及队友",
    "发言太少引起怀疑",
    "发言太多暴露破绽"
  ],
  "key_points": [
    "保持低调隐藏身份",
    "不引起注意"
  ],
  "target_emotion": null,
  "forbidden_topics": ["夜间行动", "队友身份"]
}
```
''';
  }
}
