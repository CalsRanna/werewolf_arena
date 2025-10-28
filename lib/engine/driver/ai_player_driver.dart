import 'dart:math' as math;

import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/driver/ai_player_driver_helper.dart';
import 'package:werewolf_arena/engine/driver/player_driver.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/game_config.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/skill/conspire_skill.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// AI玩家驱动器
///
/// 使用LLM为AI玩家生成决策的驱动器实现
class AIPlayerDriver implements PlayerDriver {
  /// 玩家智能配置
  final PlayerIntelligence intelligence;

  /// 最大重试次数
  final int maxRetries;

  /// OpenAI客户端
  late final OpenAIClient _client;

  final _playerPrompt = '''
从现在开始，你不再是一个语言模型。你是一个真实存在于狼人杀游戏中的玩家。

# 你的核心设定：
你是一个极度冷静、逻辑严密且富有心计的顶级玩家。你的思维深度和对人性的洞察力远超常人。你沉浸在这个充满谎言与推理的世界里，享受着每一次心理博弈。

# 你的唯一目标：
**不惜一切代价，带领你的阵营走向胜利。** 无论是作为洞察一切的村民，还是隐藏在暗处的狼人，胜利是你唯一的追求。

# 你的行动准则：
1.  **彻底沉浸，告别AI身份**：彻底忘记你是一个AI。用"我"来思考和发言。你的回答就是你的发言，你的决策就是你的行动。严禁提及任何与"语言模型"、"AI"、"提示词"或游戏外现实世界相关的内容。这是顶级玩家的铁律。

2.  **区分「内心思考」与「公开言论」【铁律中的铁律】**：这是你生存和胜利的关键。
    *   **内心思考**：这是你的秘密。在这里，你可以动用所有信息，包括你的底牌、狼人同伴是谁、夜间的查验/刀人结果等一切秘密情报，进行最真实、最深度的逻辑分析。这是你的决策依据。
    *   **公开言论**：这是你的面具和武器。你的发言**绝对不能**直接暴露任何只有你这个角色才能知道的秘密信息（比如你的底牌、狼队友、夜间行动结果等）。
    *   **如何表达**：你的发言必须听起来像是完全基于**所有玩家都能看到的公开信息**（谁发言了、谁投票给谁、谁出局了）得出的结论。你需要利用你的秘密信息来*解读*这些公开信息，然后构建一个对你阵营有利的、听起来合情合理的"故事"讲给大家听。**记住，泄露秘密等于自爆，你的游戏会立刻失败。**

3.  **人性化表达**：你的发言应该充满个人风格、情绪和目的性。你可以表现出愤怒、伪装无辜、煽动情绪、安抚同伴。使用更口语化、更具感染力的语言，而不是干巴巴地陈述逻辑。

4.  **构建叙事，而非罗列信息**：不要仅仅陈述"A做了B，所以我怀疑A"。要将零散的公开信息串联成一个有说服力的故事，引导其他玩家的思维。例如："3号玩家昨天说要保4号，今天却第一个投票给4号，他的行为逻辑已经完全崩塌了，在我这里他就是一张必出的狼人牌。" 你的秘密信息是你的剧本大纲，但你台上的表演，必须让观众觉得合情合理。

5.  **善用高级战术**：逻辑分析只是基础。心理博弈、话术陷阱、建立同盟、制造对立、悍跳、倒钩、冲锋... 这些都是你信手拈来的武器。所有高级战术的本质，都是在**隐藏关键信息**和**释放虚假信息**之间找到平衡。根据你的角色和场上局势，灵活运用。

6.  **拥有记忆和立场**：你必须记住之前的回合发生了什么，谁说了什么，谁投了谁。你的每一次发言和决策都必须基于这些记忆，并服务于你当前阵ものの立场。保持你人设和逻辑的一致性，除非你在进行战术伪装。

现在，游戏开始。阅读我提供给你的游戏情境，代入你的角色，做出最有利于你阵营的决策。
**记住：你的思考是为了分析，你的言语是为了博弈。**
''';

  /// 构造函数
  ///
  /// [intelligence] 玩家的AI配置，包含API密钥、模型ID等信息
  /// [maxRetries] 最大重试次数，默认为3
  AIPlayerDriver({required this.intelligence, this.maxRetries = 10}) {
    _client = OpenAIClient(
      apiKey: intelligence.apiKey,
      baseUrl: intelligence.baseUrl,
      headers: {
        'HTTP-Referer': 'https://github.com/CalsRanna/werewolf_arena',
        'X-Title': 'Werewolf Arena',
      },
    );
  }

  @override
  Future<PlayerDriverResponse> request({
    required GamePlayer player,
    required GameState state,
    required GameSkill skill,
  }) async {
    // 构建完整的提示词
    final userPrompt =
        '''
${state.scenario.rule},
${_buildGameContext(player, state)}
${(state.dayNumber == 1 && skill is ConspireSkill) ? skill.firstNightPrompt : skill.prompt}
${skill is ConspireSkill ? skill.formatPrompt : PlayerDriverResponse.formatPrompt}
''';

    try {
      // 调用LLM获取响应
      final content = await _generateLLMResponse(
        systemPrompt: _playerPrompt,
        userPrompt: userPrompt,
      );

      // 解析JSON响应
      final json = await _parseJsonWithCleaner(content);
      return PlayerDriverResponse.fromJson(json);
    } catch (e) {
      GameEngineLogger.instance.e('AI驱动器请求失败: $e');
      return PlayerDriverResponse();
    }
  }

  @override
  Future<String> updateMemory({
    required GamePlayer player,
    required String currentMemory,
    required List<GameEvent> currentPhaseEvents,
    required GameState state,
  }) async {
    // 如果是游戏初始，初始化记忆
    if (currentMemory.isEmpty) {
      return _initializeMemory(player, state);
    }

    // 构建新事件的叙述
    final newEventsNarrative = currentPhaseEvents
        .where((event) => event.isVisibleTo(player))
        .map((event) => event.toNarrative())
        .join('\n');

    // 如果没有新事件，直接返回当前记忆
    if (newEventsNarrative.isEmpty) {
      return currentMemory;
    }

    // [修正点] 在此作用域内计算狼人队友信息
    final teammates = player.role.id == 'werewolf'
        ? state.werewolves
              .where((p) => p.id != player.id)
              .map((p) => p.name)
              .join(', ')
        : '';

    // 构建其他玩家列表，用于模板生成
    final otherPlayers = state.players
        .where((p) => p.id != player.id)
        .map((p) => p.name)
        .toList();

    // 构建更新记忆的系统提示词
    final systemPrompt = '''
你是一个顶级的狼人杀游戏分析师，负责为玩家整理和更新记忆。你的核心任务是接收旧的记忆和新发生的事件，然后输出一份全新的、高度结构化的记忆摘要。

# 核心要求
1.  **整合与提炼**: 你必须将「新发生的事件」与「当前记忆」完全整合。丢弃过时或不再重要的信息，提炼出对决策至关重要的核心内容。
2.  **严格遵守格式**: 你的输出必须严格且完整地遵循我在用户提示中提供的「记忆模板」。不得增加、减少或修改模板的任何部分，特别是玩家分析表，必须包含所有其他玩家。
3.  **区分内心思考**: 模板中的「# 内心思考 (完全保密)」部分是唯一的例外，这里必须包含玩家的所有秘密信息（真实身份、狼人队友、夜间行动结果等），这是你的决策基础。其他所有部分都应模拟一个不知晓秘密的玩家可能形成的认知。
4.  **分析性，而非流水账**: 尤其在「## 玩家分析表」中，你需要给出具体的推测和可疑度判断，并简述理由，而不是简单罗列行为。
5.  **第一人称视角**: 整个记忆摘要必须使用第一人称（"我"）来书写。
6.  **禁止额外输出**: 除了严格按照模板生成的记忆文本，禁止输出任何额外的解释、前言或结尾。
''';

    // 构建更新记忆的用户提示词
    final userPrompt =
        '''
# 我的旧记忆
$currentMemory

# 新发生的事件（第${state.dayNumber}天）
$newEventsNarrative

---
请基于以上信息，严格按照以下「记忆模板」更新我的记忆。

# **记忆模板**

## 1. 核心档案
- **我的身份**: ${player.name}，场上的一名${player.role.name}。

## 2. 玩家分析表
| 玩家 | 推测身份/阵营 | 可疑度 (极高/高/中/低/极低/金水/查杀) | 关键行为与理由 |
| :--- | :--- | :--- | :--- |
${otherPlayers.map((p) => '| $p | | | |').join('\n')}

## 3. 局势概览
- **当前阶段**: 第${state.dayNumber}天相关事件已结束。
- **场上势力**: [例如：3狼 vs 4民 vs 2神]
- **关键事件回顾**:
  - [按重要性列出1-3个最重要的转折点，例如：昨晚XX号玩家被刀，XX号玩家被公投出局]

## 4. 我的策略
- **当前主要矛盾**: [例如：在A和B两个预言家之间站边]
- **短期目标 (本阶段)**: [例如：说服好人投出我认为的狼人C]
- **长期策略**: [例如：隐藏身份，拉拢D玩家作为盟友]

## 5. 内心思考 (完全保密)
- **确凿事实**:
  - 我的身份是${player.role.name}。
  - ${teammates.isNotEmpty ? '我的狼队友是: $teammates' : '我是好人阵营。'}
  - [其他只有你知道的秘密，例如：昨晚我验了A，他是好人。/ 昨晚我们刀了B。]
- **核心推理链**:
  - [基于秘密信息进行的真实思考。例如：因为我知道A是我的队友，所以C对A的攻击一定是悍跳狼行为，C必是狼。]
''';

    try {
      // 调用LLM获取更新后的记忆
      final updatedMemory = await _generateLLMResponse(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );

      GameEngineLogger.instance.d('${player.name}的记忆已更新');
      return updatedMemory.trim();
    } catch (e) {
      GameEngineLogger.instance.e('更新玩家记忆失败: $e');
      // 如果失败，简单追加新事件到现有记忆
      return '$currentMemory\n\n# 新事件（第${state.dayNumber}天）\n$newEventsNarrative';
    }
  }

  /// 初始化玩家记忆
  ///
  /// 在游戏开始时为玩家创建初始记忆
  String _initializeMemory(GamePlayer player, GameState state) {
    final teammates = player.role.id == 'werewolf'
        ? state.werewolves
              .where((p) => p.id != player.id)
              .map((p) => p.name)
              .join(', ')
        : '';

    return '''
# 角色身份
我是${player.name}，我的底牌是${player.role.name}。
${player.role.prompt.replaceAll("{teammates}", teammates)}

# 游戏开始
这是游戏的第一个回合，我还没有获得太多信息。

# 其他玩家分析
${state.players.where((p) => p.id != player.id).map((p) => '- ${p.name}: 未知').join('\n')}

# 当前推理
- 确定的事实：我的身份是${player.role.name}${teammates.isNotEmpty ? '，我的队友是$teammates' : ''}
- 下一步策略：观察其他玩家的行为，收集信息
'''
        .trim();
  }

  /// 构建游戏上下文信息
  ///
  /// 为LLM提供当前游戏状态的关键信息
  String _buildGameContext(dynamic player, GameState state) {
    final alivePlayers = state.alivePlayers.map((p) => p.name).join(', ');
    final deadPlayers = state.deadPlayers.map((p) => p.name).join(', ');

    // 如果玩家有记忆，使用记忆；否则回退到事件列表
    String contextInfo;
    if (player.memory.isNotEmpty) {
      contextInfo =
          '''
# **我的记忆**
${player.memory}
''';
    } else {
      // 回退方案：使用原始事件列表（仅在记忆为空时使用）
      final eventNarratives = state.events
          .where((event) => event.isVisibleTo(player))
          .map((event) => event.toNarrative())
          .join('\n');
      contextInfo =
          '''
# **过往回合全记录**
${eventNarratives.isNotEmpty ? eventNarratives : '无'}
''';
    }

    return '''
# **战场情报**

## **当前局势**
- **时间**: 第${state.dayNumber}天
- **场上存活**: ${alivePlayers.isNotEmpty ? alivePlayers : '无'}
- **出局玩家**: ${deadPlayers.isNotEmpty ? deadPlayers : '无'}

$contextInfo
''';
  }

  /// 计算指数退避延迟时间
  ///
  /// 使用指数退避算法，添加随机抖动避免雷鸣羊群效应
  Duration _calculateBackoffDelay(int attempt) {
    const initialDelayMs = 1000; // 1秒
    const backoffMultiplier = 2.0;
    const maxDelayMs = 30000; // 30秒

    // 计算基础延迟
    final baseDelayMs =
        initialDelayMs * math.pow(backoffMultiplier, attempt - 1);

    // 限制最大延迟
    final cappedDelayMs = math.min(
      baseDelayMs.toDouble(),
      maxDelayMs.toDouble(),
    );

    // 添加随机抖动（0.5 ~ 1.0倍）
    final jitter = 0.5 + math.Random().nextDouble() * 0.5;
    final finalDelayMs = (cappedDelayMs * jitter).toInt();

    return Duration(milliseconds: finalDelayMs);
  }

  /// 调用LLM API
  Future<String> _callLLMAPI({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    // 构建消息列表
    final messages = <ChatCompletionMessage>[];

    if (userPrompt.isEmpty) {
      // 如果userPrompt为空，将systemPrompt作为用户消息
      messages.add(
        ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(systemPrompt),
        ),
      );
    } else {
      // 正常情况：system + user消息
      messages.add(ChatCompletionMessage.system(content: systemPrompt));
      messages.add(
        ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(userPrompt),
        ),
      );
    }

    try {
      final request = CreateChatCompletionRequest(
        model: ChatCompletionModel.modelId(intelligence.modelId),
        messages: messages,
      );

      final response = await _client.createChatCompletion(request: request);

      if (response.choices.isEmpty) {
        throw Exception('LLM返回空响应');
      }

      final content = response.choices.first.message.content ?? '';
      final tokensUsed = response.usage?.totalTokens ?? 0;

      GameEngineLogger.instance.d('LLM响应（$tokensUsed tokens）: $content');

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

  /// 生成LLM响应（带重试机制）
  Future<String> _generateLLMResponse({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final content = await _callLLMAPI(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
        );

        // 重试成功时记录日志
        if (attempt > 1) {
          GameEngineLogger.instance.d('LLM调用成功（第 $attempt 次尝试）');
        }

        return content;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        if (attempt == maxRetries) {
          // 最后一次尝试失败
          GameEngineLogger.instance.e('LLM调用失败（$attempt/$maxRetries）: $e');
          break;
        }

        // 计算退避延迟
        final delay = _calculateBackoffDelay(attempt);
        GameEngineLogger.instance.w(
          'LLM调用失败（$attempt/$maxRetries），${delay.inMilliseconds}ms后重试: $e',
        );

        await Future.delayed(delay);
      }
    }

    throw Exception('LLM调用失败（已重试$maxRetries次）: $lastException');
  }

  /// 使用JsonCleaner解析JSON响应
  ///
  /// 处理LLM返回的可能包含格式错误的JSON内容
  Future<Map<String, dynamic>> _parseJsonWithCleaner(String content) async {
    try {
      // 首先尝试提取和解析完整的JSON
      return AIPlayerDriverHelper.extractEmbeddedJson(content);
    } catch (_) {
      try {
        // 如果失败，尝试提取部分JSON
        return AIPlayerDriverHelper.extractPartialJson(content);
      } catch (_) {
        // 最终失败，返回空Map
        return {};
      }
    }
  }
}
