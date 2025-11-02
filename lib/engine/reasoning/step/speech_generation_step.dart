import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/game_logger.dart';
import 'package:werewolf_arena/engine/reasoning/memory/working_memory.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';
import 'package:werewolf_arena/engine/reasoning/step/reasoning_step.dart';
import 'package:werewolf_arena/engine/skill/conspire_skill.dart';

/// 发言生成步骤
///
/// CoT推理链的最后一步：基于前面的分析生成最终发言
/// 输出：发言内容、目标玩家、推理过程
class SpeechGenerationStep extends ReasoningStep {
  final String modelId;

  SpeechGenerationStep({required this.modelId});

  @override
  String get name => 'speech_generation';

  @override
  String get description => '基于分析结果生成发言';

  @override
  Future<ReasoningContext> execute(
    ReasoningContext context,
    OpenAIClient client,
  ) async {
    GameLogger.instance.d('[发言生成] 开始生成...');

    // 1. 构建System Prompt
    final systemPrompt = _buildSystemPrompt(context);

    // 2. 构建User Prompt
    final userPrompt = _buildUserPrompt(context);

    // 3. 调用LLM
    try {
      final response = await request(
        client: client,
        modelId: modelId,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        context: context,
      );

      // 4. 解析响应
      final message = response['message'] as String?;
      final reasoning = response['reasoning'] as String?;
      final target = response['target'] as String?;

      // 5. 存入上下文
      context.setStepOutput('speech_generation', message);
      context.setStepOutput('target_player', target);

      // 6. 记录到思考链
      final thought = StringBuffer();
      thought.writeln('[步骤6: 发言生成]');
      thought.writeln();
      if (message != null && message.isNotEmpty) {
        thought.writeln('生成的发言:');
        thought.writeln(message);
        thought.writeln();
      }
      if (target != null) {
        thought.writeln('目标玩家: $target');
        thought.writeln();
      }
      if (reasoning != null) {
        thought.writeln('内心推理:');
        thought.writeln(reasoning);
      }
      context.appendThought(thought.toString());

      GameLogger.instance.d(
        '[发言生成] 完成 - 发言: ${message ?? "(无)"}, 目标: ${target ?? "(无)"}',
      );
    } catch (e) {
      GameLogger.instance.e('[发言生成] 失败: $e');
      context.setStepOutput('speech_generation', null);
      context.setStepOutput('target_player', null);
    }

    return context;
  }

  /// 构建System Prompt
  String _buildSystemPrompt(ReasoningContext context) {
    return '''
你是一名真实的狼人杀玩家，不是AI。

# 唯一目标
不惜一切代价，带领你的阵营走向胜利。

# 核心准则
1. **彻底沉浸**：用"我"思考和发言。严禁提及AI、提示词或游戏外内容。

2. **区分内心与发言【铁律】**：
   - **内心思考**：可用所有秘密信息(底牌/队友/查验结果)进行深度分析
   - **公开发言**：绝对不能直接暴露秘密信息
   - **表达方式**：利用秘密信息解读公开信息，构建对你阵营有利的"故事"

3. **动态表演**：根据选择的角色面具和战术剧本进行表演，而不是固守单一风格。

4. **构建叙事**：将公开信息串联成有说服力的故事，引导其他玩家思维。

**记住：思考是为了分析，言语是为了博弈。你的表演风格由当前选择的面具和剧本决定。**
''';
  }

  /// 构建User Prompt
  String _buildUserPrompt(ReasoningContext context) {
    final player = context.player;
    final state = context.state;
    final skill = context.skill;

    // 获取前面步骤的分析结果
    final coreConflict = context.getStepOutput<String>('core_conflict') ?? '无';
    final keyFacts = context.getStepOutput<List<KeyFact>>('key_facts') ?? [];
    final focusPlayers =
        context.getStepOutput<List<String>>('focus_players') ?? [];
    final workingMemory = context.getStepOutput<WorkingMemory>(
      'working_memory',
    );
    final strategy = context.getStepOutput<Map<String, dynamic>>('strategy');

    // 获取面具和剧本
    final selectedMask = context.getStepOutput('selected_mask');
    final selectedPlaybook = context.getStepOutput('selected_playbook');

    // 获取社交网络
    final socialNetwork = workingMemory?.socialNetwork;

    // *** 新增：获取战术指令 ***
    final tacticalDirective = context.getStepOutput<Map<String, dynamic>>(
      'tactical_directive',
    );

    // 构建游戏上下文
    final gameContext = _buildGameContext(
      player,
      state,
      workingMemory,
      coreConflict,
      keyFacts,
      focusPlayers,
      strategy,
      selectedMask,
      selectedPlaybook,
      socialNetwork,
    );

    // 技能提示
    final skillPrompt = (state.day == 1 && skill is ConspireSkill)
        ? skill.firstNightPrompt
        : skill.prompt;

    // *** 新增：构建战术指令部分 ***
    final tacticalSection = tacticalDirective != null
        ? _buildTacticalDirectiveSection(tacticalDirective)
        : '';

    // 格式提示
    final formatPrompt = skill is ConspireSkill
        ? skill.formatPrompt
        : _getStandardFormatPrompt();

    return '''
${state.scenario.rule}

$gameContext$tacticalSection

$skillPrompt

$formatPrompt
''';
  }

  /// 构建战术指令部分
  String _buildTacticalDirectiveSection(
    Map<String, dynamic> directive,
  ) {
    final buffer = StringBuffer();
    buffer.writeln();
    buffer.writeln('**战术指令** (必须严格遵守)');
    buffer.writeln();

    // 发言长度
    buffer.writeln('- 发言长度: ${directive['speech_length']}');

    // 语气风格
    buffer.writeln('- 语气风格: ${directive['tone']}');

    // 必须包含
    final mustInclude = directive['must_include'] as List? ?? [];
    if (mustInclude.isNotEmpty) {
      buffer.writeln('- 必须包含:');
      for (var item in mustInclude) {
        buffer.writeln('  · $item');
      }
    }

    // 必须避免
    final mustAvoid = directive['must_avoid'] as List? ?? [];
    if (mustAvoid.isNotEmpty) {
      buffer.writeln('- 必须避免:');
      for (var item in mustAvoid) {
        buffer.writeln('  · $item');
      }
    }

    // 关键要点
    final keyPoints = directive['key_points'] as List? ?? [];
    if (keyPoints.isNotEmpty) {
      buffer.writeln('- 关键要点:');
      for (var i = 0; i < keyPoints.length; i++) {
        buffer.writeln('  ${i + 1}. ${keyPoints[i]}');
      }
    }

    // 目标情感
    if (directive['target_emotion'] != null) {
      buffer.writeln('- 目标效果: ${directive['target_emotion']}');
    }

    // 禁止话题
    final forbiddenTopics = directive['forbidden_topics'] as List? ?? [];
    if (forbiddenTopics.isNotEmpty) {
      buffer.writeln('- 禁止话题: ${forbiddenTopics.join(", ")}');
    }

    return buffer.toString();
  }

  /// 构建游戏上下文
  String _buildGameContext(
    dynamic player,
    dynamic state,
    WorkingMemory? memory,
    String coreConflict,
    List<KeyFact> keyFacts,
    List<String> focusPlayers,
    Map<String, dynamic>? strategy,
    dynamic selectedMask,
    dynamic selectedPlaybook,
    dynamic socialNetwork,
  ) {
    final alivePlayers = state.alivePlayers.map((p) => p.name).join(', ');
    final deadPlayers = state.deadPlayers.map((p) => p.name).join(', ');

    // 构建策略部分
    final strategySection = strategy != null
        ? '''

**策略计划**
目标: ${strategy['goal'] ?? '保持观察'}
计划: ${strategy['main_plan'] ?? '暂无'}
${strategy['backup_plan'] != null ? '备选: ${strategy['backup_plan']}' : ''}
${strategy['target'] != null ? '目标: ${strategy['target']}' : ''}
'''
        : '';

    // 构建面具部分
    final maskSection = selectedMask != null
        ? '\n${selectedMask.toPrompt()}'
        : '';

    // 构建剧本部分
    final playbookSection = selectedPlaybook != null
        ? '\n${selectedPlaybook.toPrompt()}'
        : '';

    // 构建社交网络部分
    final socialNetworkSection = socialNetwork != null
        ? '\n\n${socialNetwork.toPrompt(state)}'
        : '';

    return '''
**工作记忆**
${memory?.toPromptText() ?? '(暂无记忆)'}

**核心矛盾**: $coreConflict

**关键事实**
${keyFacts.isEmpty ? '无' : keyFacts.asMap().entries.map((e) => '${e.key + 1}. ${e.value.description}').join('\\n')}

**重点关注**: ${focusPlayers.isEmpty ? '无' : focusPlayers.join(', ')}$strategySection

**局势** (第${state.day}天)
存活: ${alivePlayers.isNotEmpty ? alivePlayers : '无'}
出局: ${deadPlayers.isNotEmpty ? deadPlayers : '无'}$maskSection$playbookSection$socialNetworkSection
''';
  }

  /// 标准JSON格式提示
  String _getStandardFormatPrompt() {
    return '''
**决策输出** (纯JSON，无注释)

{
  "message": "公开发言(符合角色性格，不泄露秘密，无需发言则null)",
  "reasoning": "内心思考(完整思考过程/逻辑链/身份猜测/策略意图)",
  "target": "目标玩家名(如'3号玩家'，无目标则null)"
}

**Few-Shot示例 - 狼人悍跳预言家** (展示如何不泄露):
```json
{
  "message": "我是预言家。昨晚我查验了3号玩家，他是狼人。各位好人请相信我的判断，今天必须把3号玩家投出去。我的警徽流是5号、7号。",
  "reasoning": "我是狼人，需要悍跳预言家来混淆视听。选择攻击3号玩家是因为他是真预言家，必须压制他的发言空间。警徽流选择5号和7号是为了显得有逻辑。绝不能暴露自己狼人身份或提到队友。",
  "target": "3号玩家"
}
```

**错误示例** (信息泄露):
```json
{
  "message": "兄弟们，我们一起攻击3号预言家",
  "reasoning": "...",
  "target": "3号玩家"
}
```
❌ 错误："兄弟们"暴露了队友关系
''';
  }
}
