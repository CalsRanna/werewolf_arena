import 'dart:convert';

import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/mask/mask_library.dart';
import 'package:werewolf_arena/engine/mask/role_mask.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_step.dart';

/// 面具选择步骤（LLM版本）
///
/// 从面具库中选择最适合当前场景的面具
/// 使用LLM分析当前局势，从推荐面具中选择最优方案
class MaskSelectionStep extends ReasoningStep {
  final String modelId;

  MaskSelectionStep({required this.modelId});

  @override
  String get name => 'mask_selection';

  @override
  String get description => '选择合适的角色面具';

  @override
  Future<ReasoningContext> execute(
    ReasoningContext context,
    OpenAIClient client,
  ) async {
    GameEngineLogger.instance.d('[面具选择] 开始选择...');

    final player = context.player;
    final state = context.state;

    // 1. 从面具库获取推荐列表
    final recommendedMasks = MaskLibrary.recommend(
      state: state,
      player: player,
    );

    // 2. 构建Prompt并调用LLM
    try {
      final strategy = context.getStepOutput<Map<String, dynamic>>('strategy');
      final systemPrompt = _buildSystemPrompt();
      final userPrompt = _buildUserPrompt(
        context,
        recommendedMasks,
        strategy,
      );

      final response = await _call(
        client: client,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        context: context,
      );

      // 3. 解析响应
      final selectedMaskId = _parseResponse(response);

      // 4. 查找选中的面具
      final RoleMask selectedMask;
      if (selectedMaskId != null) {
        selectedMask = recommendedMasks.firstWhere(
          (m) => m.id == selectedMaskId,
          orElse: () => recommendedMasks.first,
        );
      } else {
        selectedMask = recommendedMasks.first;
      }

      // 5. 存入上下文
      context.setStepOutput('selected_mask', selectedMask);

      // 6. 记录到思考链
      context.appendThought('''
[步骤5: 面具选择]
选择的面具: ${selectedMask.name}
面具描述: ${selectedMask.description}
''');

      GameEngineLogger.instance.d(
        '[面具选择] 完成 - 选择了: ${selectedMask.name}',
      );
    } catch (e) {
      GameEngineLogger.instance.e('[面具选择] 失败: $e');
      // 降级：使用默认面具
      final fallbackMask = MaskLibrary.getDefault();
      context.setStepOutput('selected_mask', fallbackMask);
      context.appendThought('''
[步骤5: 面具选择]
选择的面具: ${fallbackMask.name}（降级选择）
面具描述: ${fallbackMask.description}
''');
    }

    return context;
  }

  /// 构建System Prompt
  String _buildSystemPrompt() {
    return '''
你是狼人杀表演专家。基于当前局势和策略，选择最合适的角色面具来伪装发言风格。

要点：
1. 分析当前需要展现的人设（如委屈、强势、理性等）
2. 评估各个面具的适用场景
3. 选择最能配合策略目标的面具

输出：选中的面具ID
''';
  }

  /// 构建User Prompt
  String _buildUserPrompt(
    ReasoningContext context,
    List<RoleMask> recommendedMasks,
    Map<String, dynamic>? strategy,
  ) {
    final player = context.player;
    final state = context.state;
    final skill = context.skill;

    // 构建面具列表
    final maskDescriptions = StringBuffer();
    for (var i = 0; i < recommendedMasks.length; i++) {
      final mask = recommendedMasks[i];
      maskDescriptions.writeln('''
**面具${i + 1}: ${mask.name}** (ID: ${mask.id})
描述: ${mask.description}
语气特征: ${mask.tone}
语言风格: ${mask.languageStyle}
---
''');
    }

    return '''
**我的信息**
我是${player.name}，角色：${player.role.name}
当前行动：${skill.name}

**局势** (第${state.day}天)
存活人数: ${state.alivePlayers.length}

**我的策略目标**
${strategy?['goal'] ?? '保持观察'}

**候选面具**
$maskDescriptions

---

**任务**: 分析候选面具，选择最适合当前策略和场景的一个，用于塑造发言风格。

输出JSON：
```json
{
  "selected_mask_id": "面具ID",
  "reason": "选择理由(1-2句)"
}
```

**Few-Shot示例**:

场景1 - 需要强势起跳:
```json
{
  "selected_mask_id": "confident_leader",
  "reason": "需要强势宣布身份，自信领袖面具能增加发言说服力"
}
```

场景2 - 被怀疑需要澄清:
```json
{
  "selected_mask_id": "wronged_good",
  "reason": "被质疑身份，用委屈好人面具表达无奈，博取同情"
}
```

场景3 - 需要低调观察:
```json
{
  "selected_mask_id": "rational_analyst",
  "reason": "保持低调收集信息，理性分析师面具既不突出也不沉默"
}
```
''';
  }

  /// 调用LLM
  Future<String> _call({
    required OpenAIClient client,
    required String systemPrompt,
    required String userPrompt,
    required ReasoningContext context,
  }) async {
    final messages = <ChatCompletionMessage>[];
    messages.add(ChatCompletionMessage.system(content: systemPrompt));
    messages.add(ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string(userPrompt),
    ));

    final request = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(modelId),
      messages: messages,
    );

    final response = await client.createChatCompletion(request: request);
    if (response.choices.isEmpty) {
      throw Exception('response.choices.isEmpty');
    }

    final content = response.choices.first.message.content ?? '';
    final tokensUsed = response.usage?.totalTokens ?? 0;
    context.recordStepTokens(name, tokensUsed);

    return content;
  }

  /// 解析LLM响应
  String? _parseResponse(String response) {
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
      return json['selected_mask_id'] as String?;
    } catch (e) {
      GameEngineLogger.instance.e(
        '[面具选择] JSON解析失败: $e\nResponse: $response',
      );
      return null;
    }
  }
}
