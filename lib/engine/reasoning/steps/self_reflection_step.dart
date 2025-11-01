import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/driver/ai_player_driver_helper.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/memory/working_memory.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_step.dart';

/// 自我反思步骤
///
/// CoT推理链的质量控制步骤：检查发言质量和信息泄露
/// 输出：评估结果、修正建议、可选的重新生成
class SelfReflectionStep extends ReasoningStep {
  final String modelId;

  /// 是否启用重新生成（如果发现严重问题）
  final bool enableRegeneration;

  SelfReflectionStep({
    required this.modelId,
    this.enableRegeneration = false,
  });

  @override
  String get name => 'self_reflection';

  @override
  String get description => '评估发言质量并检查信息泄露';

  @override
  Future<ReasoningContext> execute(
    ReasoningContext context,
    OpenAIClient client,
  ) async {
    GameEngineLogger.instance.d('[自我反思] 开始评估...');

    // 获取生成的发言
    final message = context.getStepOutput<String>('speech_generation');
    final reasoning = context.getStepOutput<String>('reasoning');

    if (message == null || message.isEmpty) {
      GameEngineLogger.instance.d('[自我反思] 跳过 - 没有发言内容');
      context.setStepOutput('self_reflection_result', 'skipped');
      return context;
    }

    // 构建System Prompt
    final systemPrompt = _buildSystemPrompt();

    // 构建User Prompt
    final userPrompt = _buildUserPrompt(context, message, reasoning);

    // 调用LLM
    try {
      final response = await _call(
        client: client,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        context: context,
      );

      // 解析响应
      final json = await _parseJson(response);

      // 健壮的类型转换（LLM可能返回字符串）
      final hasLeakage = _parseBool(json['has_leakage']) ?? false;
      final leakageDescription = json['leakage_description'] as String?;
      final qualityScore = _parseInt(json['quality_score']) ?? 80;
      final suggestions = json['suggestions'] as List?;

      // 记录评估结果
      context.setStepOutput('self_reflection_result', {
        'has_leakage': hasLeakage,
        'leakage_description': leakageDescription,
        'quality_score': qualityScore,
        'suggestions': suggestions,
      });

      // 记录到思考链
      final thought = StringBuffer();
      thought.writeln('[步骤7: 自我反思]');
      thought.writeln();
      thought.writeln('质量评分: $qualityScore/100');

      if (hasLeakage) {
        GameEngineLogger.instance.w(
          '[自我反思] 警告 - 检测到信息泄露: $leakageDescription',
        );
        thought.writeln('⚠️ 信息泄露检测: 是');
        thought.writeln('泄露描述: $leakageDescription');

        // 如果启用了重新生成，则标记需要重新生成
        if (enableRegeneration) {
          context.setStepOutput('needs_regeneration', true);
          thought.writeln('需要重新生成: 是');
        }
      } else {
        GameEngineLogger.instance.d(
          '[自我反思] 通过 - 质量评分: $qualityScore/100',
        );
        thought.writeln('✓ 信息泄露检测: 否');
      }

      if (suggestions != null && suggestions.isNotEmpty) {
        thought.writeln();
        thought.writeln('改进建议:');
        for (var i = 0; i < suggestions.length; i++) {
          thought.writeln('${i + 1}. ${suggestions[i]}');
        }
      }

      context.appendThought(thought.toString());
    } catch (e) {
      GameEngineLogger.instance.e('[自我反思] 失败: $e');
      context.setStepOutput('self_reflection_result', 'error');
    }

    return context;
  }

  /// 构建System Prompt
  String _buildSystemPrompt() {
    return '''
你是狼人杀发言质量评估专家，检查AI发言是否泄露秘密信息。

**信息泄露检测（核心）**

严重泄露（必须标记）:
- 暴露真实身份/队友信息
- 泄露夜间行动结果（除非该角色应公开）
- 使用只有特定角色才知道的信息

常见泄露: 狼人提"队友"/"我们狼人"；预言家不该公开时说查验；守卫暗示守护对象

合理表达（不算泄露）: 基于公开信息推理、声称身份（策略）、攻击/支持他人

**质量评估**
高分(80-100): 逻辑清晰、符合人设、语言自然、有明确目的
中分(60-79): 逻辑通顺、语言稍硬
低分(<60): 逻辑混乱、机器感强

**改进建议**: 若有问题，给出具体建议
''';
  }

  /// 构建User Prompt
  String _buildUserPrompt(
    ReasoningContext context,
    String message,
    String? reasoning,
  ) {
    final player = context.player;
    final state = context.state;

    // 获取工作记忆
    final workingMemory = context.getStepOutput<WorkingMemory>('working_memory');

    // 构建秘密信息部分（用于检查泄露）
    final secretInfo = workingMemory != null
        ? workingMemory.secretKnowledge.toText()
        : '';

    return '''
**待评估发言**

玩家: ${player.name} (${player.role.name})
回合: 第${state.day}天

发言内容:
$message

${reasoning != null ? '''内心推理:
$reasoning
''' : ''}

**秘密信息** (仅用于泄露检测)
$secretInfo

---

评估发言，检查泄露并评分。返回JSON:
{
  "has_leakage": false,
  "leakage_description": null,
  "quality_score": 85,
  "suggestions": []
}

注意: 声称身份是策略(不算泄露)，基于公开信息推理不算泄露
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

  /// 解析JSON
  Future<Map<String, dynamic>> _parseJson(String content) async {
    try {
      return AIPlayerDriverHelper.extractEmbeddedJson(content);
    } catch (_) {
      try {
        return AIPlayerDriverHelper.extractPartialJson(content);
      } catch (_) {
        return {
          'has_leakage': false,
          'quality_score': 80,
          'suggestions': [],
        };
      }
    }
  }

  /// 健壮的bool解析（处理字符串"true"/"false"）
  bool? _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
    }
    return null;
  }

  /// 健壮的int解析（处理字符串数字）
  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
