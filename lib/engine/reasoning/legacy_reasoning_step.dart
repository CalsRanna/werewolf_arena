import 'dart:math' as math;

import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/driver/ai_player_driver_helper.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/player/ai_player.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_step.dart';
import 'package:werewolf_arena/engine/skill/conspire_skill.dart';

/// 遗留推理步骤
///
/// 将现有的单次LLM调用逻辑包装成一个推理步骤
/// 这是一个过渡方案，保证新架构下游戏能正常运行
/// 后续会逐步拆分为多个细粒度的推理步骤
class LegacyReasoningStep extends ReasoningStep {
  /// 最大重试次数
  final int maxRetries;

  /// 玩家的智能配置（包含模型ID、API密钥等）
  final String modelId;

  LegacyReasoningStep({
    this.maxRetries = 10,
    required this.modelId,
  });

  @override
  String get name => 'legacy_single_call';

  @override
  String get description => '遗留的单次LLM调用（完整prompt）';

  @override
  Future<ReasoningContext> execute(
    ReasoningContext context,
    OpenAIClient client,
  ) async {
    final player = context.player;

    // 构建完整的提示词（使用现有逻辑）
    final systemPrompt = _getPlayerPrompt(player);
    final userPrompt = _buildUserPrompt(context);

    // 调用LLM（带重试）
    try {
      final response = await _requestWithRetry(
        client: client,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );

      // 解析JSON响应
      final json = await _parseJsonWithCleaner(response);

      // 提取结果
      final message = json['message'] as String?;
      final reasoning = json['reasoning'] as String?;
      final target = json['target'] as String?;

      // 更新上下文
      context.setStepOutput('speech_generation', message);
      context.setStepOutput('target_player', target);
      context.appendThought(reasoning ?? '(无内心思考)');

      GameEngineLogger.instance.d(
        '${player.name} 决策完成\n'
        '发言: ${message ?? "(无发言)"}\n'
        '目标: ${target ?? "(无目标)"}',
      );
    } catch (e) {
      GameEngineLogger.instance.e(
        '${player.name} LLM请求失败: $e',
      );
      // 发生错误时返回空结果
      context.setStepOutput('speech_generation', null);
      context.setStepOutput('target_player', null);
      context.appendThought('(推理失败: $e)');
    }

    return context;
  }

  /// 构建System Prompt（简化版）
  String _getPlayerPrompt(GamePlayer player) {
    if (player is! AIPlayer) return '';
    return '''
从现在开始，你不再是一个语言模型。你是一个真实存在于狼人杀游戏中的玩家。

# 你的唯一目标：
**不惜一切代价，带领你的阵营走向胜利。** 无论是作为洞察一切的村民，还是隐藏在暗处的狼人，胜利是你唯一的追求。

# 你的行动准则：
1.  **彻底沉浸，告别AI身份**：彻底忘记你是一个AI。用"我"来思考和发言。你的回答就是你的发言，你的决策就是你的行动。严禁提及任何与"语言模型"、"AI"、"提示词"或游戏外现实世界相关的内容。这是顶级玩家的铁律。

2.  **区分「内心思考」与「公开言论」【铁律中的铁律】**：这是你生存和胜利的关键。
    *   **内心思考**：这是你的秘密。在这里，你可以动用所有信息，包括你的底牌、狼人同伴是谁、夜间的查验/刀人结果等一切秘密情报，进行最真实、最深度的逻辑分析。这是你的决策依据。
    *   **公开言论**：这是你的面具和武器。你的发言**绝对不能**直接暴露任何只有你这个角色才能知道的秘密信息（比如你的底牌、狼队友、夜间行动结果等）。
    *   **如何表达**：你的发言必须听起来像是完全基于**所有玩家都能看到的公开信息**（谁发言了、谁投票给谁、谁出局了）得出的结论。你需要利用你的秘密信息来*解读*这些公开信息，然后构建一个对你阵营有利的、听起来合情合理的"故事"讲给大家听。**记住，泄露秘密等于自爆，你的游戏会立刻失败。**

3.  **构建叙事，而非罗列信息**：不要仅仅陈述"A做了B，所以我怀疑A"。要将零散的公开信息串联成一个有说服力的故事，引导其他玩家的思维。例如："3号玩家昨天说要保4号，今天却第一个投票给4号，他的行为逻辑已经完全崩塌了，在我这里他就是一张必出的狼人牌。" 你的秘密信息是你的剧本大纲，但你台上的表演，必须让观众觉得合情合理。

4.  **善用高级战术**：逻辑分析只是基础。心理博弈、话术陷阱、建立同盟、制造对立、悍跳、倒钩、冲锋... 这些都是你信手拈来的武器。所有高级战术的本质，都是在**隐藏关键信息**和**释放虚假信息**之间找到平衡。根据你的角色和场上局势，灵活运用。

5.  **拥有记忆和立场**：你必须记住之前的回合发生了什么，谁说了什么，谁投了谁。你的每一次发言和决策都必须基于这些记忆，并服务于你当前阵营的立场。保持你人设和逻辑的一致性，除非你在进行战术伪装。

现在，游戏开始。阅读我提供给你的游戏情境，代入你的角色，做出最有利于你阵营的决策。
**记住：你的思考是为了分析，你的言语是为了博弈。**
''';
  }

  /// 构建User Prompt（使用现有逻辑）
  String _buildUserPrompt(ReasoningContext context) {
    final player = context.player;
    final state = context.state;
    final skill = context.skill;

    final gameContext = _buildGameContext(player, state);
    final skillPrompt =
        (state.day == 1 && skill is ConspireSkill) ? skill.firstNightPrompt : skill.prompt;
    final formatPrompt = skill is ConspireSkill
        ? skill.formatPrompt
        : _getStandardFormatPrompt();

    return '''
${state.scenario.rule}

$gameContext

$skillPrompt

$formatPrompt
''';
  }

  /// 构建游戏上下文
  String _buildGameContext(GamePlayer player, GameState state) {
    final alivePlayers = state.alivePlayers.map((p) => p.name).join(', ');
    final deadPlayers = state.deadPlayers.map((p) => p.name).join(', ');
    final eventNarratives = state.events
        .where((event) => event.isVisibleTo(player))
        .map((event) => event.toNarrative())
        .join('\n');

    return '''
# **战场情报**

## **事件历史**
${eventNarratives.isNotEmpty ? eventNarratives : '无'}

## **当前局势**
- **时间**: 第${state.day}天
- **场上存活**: ${alivePlayers.isNotEmpty ? alivePlayers : '无'}
- **出局玩家**: ${deadPlayers.isNotEmpty ? deadPlayers : '无'}
''';
  }

  /// 标准JSON格式提示
  String _getStandardFormatPrompt() {
    return '''
# **你的决策输出**

现在，请根据你的思考，做出最终决策。你的决策必须以一个【纯净的JSON对象】格式提交，绝对不要在JSON前后添加任何注释、解释或Markdown标记（例如 ```json）。

JSON结构如下:
{
  "message": "【我的公开表演】你最终决定在当前环节公开说出的话。这部分内容将向所有人展示，它必须服务于你的最终目标。语言要符合你的角色性格，可以煽动、可以伪装、也可以真诚。如果当前环节不需要发言，则为 null。",
  "reasoning": "【我的内心独白】在这里详细记录你的完整思考过程、逻辑链、对其他玩家身份的猜测、你的策略意图以及你为什么要这么做。这部分只有你自己能看到，是你制定策略的秘密基地。",
  "target": "【我的行动目标】你此次行动/发言/投票所针对的玩家名称，例如 '3号玩家'。如果没有具体目标，则为 null。"
}
''';
  }

  /// 带重试的请求
  Future<String> _requestWithRetry({
    required OpenAIClient client,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await _call(
          client: client,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
        );
        await _parseJsonWithCleaner(response);
        return response;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        if (attempt == maxRetries) {
          GameEngineLogger.instance.e('请求失败（$attempt/$maxRetries）: $e');
          break;
        }

        final delay = _calculateBackoffDelay(attempt);
        GameEngineLogger.instance.w(
          '请求失败（$attempt/$maxRetries），${delay.inSeconds}s后重试: $e',
        );

        await Future.delayed(delay);
      }
    }

    throw Exception('请求失败（已重试$maxRetries次）: $lastException');
  }

  /// 单次LLM调用
  Future<String> _call({
    required OpenAIClient client,
    required String systemPrompt,
    required String userPrompt,
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

    try {
      final response = await client.createChatCompletion(request: request);
      if (response.choices.isEmpty) {
        throw Exception('response.choices.isEmpty');
      }
      final content = response.choices.first.message.content ?? '';
      final tokensUsed = response.usage?.totalTokens ?? 0;
      GameEngineLogger.instance.d('\nUsage: $tokensUsed tokens\n$content');
      return content;
    } on OpenAIClientException catch (e) {
      final errorInfo = 'OpenAI API错误: ${e.message}';
      if (e.code != null) {
        throw Exception('$errorInfo (Code: ${e.code})');
      }
      throw Exception(errorInfo);
    } catch (e) {
      throw Exception('LLM API调用异常: $e');
    }
  }

  /// 解析JSON（使用现有的helper）
  Future<Map<String, dynamic>> _parseJsonWithCleaner(String content) async {
    try {
      return AIPlayerDriverHelper.extractEmbeddedJson(content);
    } catch (_) {
      try {
        return AIPlayerDriverHelper.extractPartialJson(content);
      } catch (_) {
        return {};
      }
    }
  }

  /// 计算退避延迟
  Duration _calculateBackoffDelay(int attempt) {
    const initialDelayMs = 1000;
    const backoffMultiplier = 2.0;
    const maxDelayMs = 30000;

    final baseDelayMs =
        initialDelayMs * math.pow(backoffMultiplier, attempt - 1);
    final cappedDelayMs = math.min(
      baseDelayMs.toDouble(),
      maxDelayMs.toDouble(),
    );

    return Duration(milliseconds: cappedDelayMs.toInt());
  }
}
