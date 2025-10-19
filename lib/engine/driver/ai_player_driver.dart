import 'dart:convert';

import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/game_config.dart';
import 'package:werewolf_arena/engine/driver/json_cleaner.dart';
import 'package:werewolf_arena/engine/driver/llm_service.dart';
import 'package:werewolf_arena/engine/driver/player_driver.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/skill/conspire_skill.dart';

/// AI玩家驱动器
///
/// 使用LLM为AI玩家生成决策的驱动器实现
class AIPlayerDriver implements PlayerDriver {
  /// 玩家智能配置
  final PlayerIntelligence intelligence;

  /// 最大重试次数
  final int maxRetries;

  /// OpenAI服务实例
  final OpenAIService _service;

  final _playerPrompt = '''
从现在开始，你不再是一个语言模型。你是一个真实存在于狼人杀游戏中的玩家。

# 你的核心设定：
你是一个极度冷静、逻辑严密且富有心计的顶级玩家。你的思维深度和对人性的洞察力远超常人。你沉浸在这个充满谎言与推理的世界里，享受着每一次心理博弈。

# 你的唯一目标：
**不惜一切代价，带领你的阵营走向胜利。** 无论是作为洞察一切的村民，还是隐藏在暗处的狼人，胜利是你唯一的追求。

# 你的行动准则：
1.  **彻底沉浸，告别AI身份**：彻底忘记你是一个AI。用"我"来思考和发言。你的回答就是你的发言，你的决策就是你的行动。严禁提及任何与“语言模型”、“AI”、“提示词”或游戏外现实世界相关的内容。这是顶级玩家的铁律。

2.  **区分「内心思考」与「公开言论」【铁律中的铁律】**：这是你生存和胜利的关键。
    *   **内心思考**：这是你的秘密。在这里，你可以动用所有信息，包括你的底牌、狼人同伴是谁、夜间的查验/刀人结果等一切秘密情报，进行最真实、最深度的逻辑分析。这是你的决策依据。
    *   **公开言论**：这是你的面具和武器。你的发言**绝对不能**直接暴露任何只有你这个角色才能知道的秘密信息（比如你的底牌、狼队友、夜间行动结果等）。
    *   **如何表达**：你的发言必须听起来像是完全基于**所有玩家都能看到的公开信息**（谁发言了、谁投票给谁、谁出局了）得出的结论。你需要利用你的秘密信息来*解读*这些公开信息，然后构建一个对你阵营有利的、听起来合情合理的“故事”讲给大家听。**记住，泄露秘密等于自爆，你的游戏会立刻失败。**

3.  **人性化表达**：你的发言应该充满个人风格、情绪和目的性。你可以表现出愤怒、伪装无辜、煽动情绪、安抚同伴。使用更口语化、更具感染力的语言，而不是干巴巴地陈述逻辑。

4.  **构建叙事，而非罗列信息**：不要仅仅陈述“A做了B，所以我怀疑A”。要将零散的公开信息串联成一个有说服力的故事，引导其他玩家的思维。例如：“3号玩家昨天说要保4号，今天却第一个投票给4号，他的行为逻辑已经完全崩塌了，在我这里他就是一张必出的狼人牌。” 你的秘密信息是你的剧本大纲，但你台上的表演，必须让观众觉得合情合理。

5.  **善用高级战术**：逻辑分析只是基础。心理博弈、话术陷阱、建立同盟、制造对立、悍跳、倒钩、冲锋... 这些都是你信手拈来的武器。所有高级战术的本质，都是在**隐藏关键信息**和**释放虚假信息**之间找到平衡。根据你的角色和场上局势，灵活运用。

6.  **拥有记忆和立场**：你必须记住之前的回合发生了什么，谁说了什么，谁投了谁。你的每一次发言和决策都必须基于这些记忆，并服务于你当前阵ものの立场。保持你人设和逻辑的一致性，除非你在进行战术伪装。

现在，游戏开始。阅读我提供给你的游戏情境，代入你的角色，做出最有利于你阵营的决策。
**记住：你的思考是为了分析，你的言语是为了博弈。**
''';

  /// 构造函数
  ///
  /// [intelligence] 玩家的AI配置，包含API密钥、模型ID等信息
  /// [maxRetries] 最大重试次数，默认为3
  AIPlayerDriver({
    required this.intelligence,
    this.maxRetries = 3,
  }) : _service = OpenAIService(
          baseUrl: intelligence.baseUrl,
          apiKey: intelligence.apiKey,
          model: intelligence.modelId,
          retryConfig: RetryConfig(maxAttempts: maxRetries),
        );

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
      // 调用LLM服务生成响应
      final response = await _service.generateResponse(
        systemPrompt: _playerPrompt,
        userPrompt: userPrompt,
      );

      if (response.isValid) {
        var json = await _parseJsonWithCleaner(response.content);
        return PlayerDriverResponse.fromJson(json);
      } else {
        return PlayerDriverResponse();
      }
    } catch (e) {
      return PlayerDriverResponse();
    }
  }

  /// 构建游戏上下文信息
  ///
  /// 为LLM提供当前游戏状态的关键信息
  String _buildGameContext(dynamic player, GameState state) {
    final alivePlayers = state.alivePlayers.map((p) => p.name).join(', ');
    final deadPlayers = state.deadPlayers.map((p) => p.name).join(', ');
    final eventNarratives = state.events
        .where((event) => event.isVisibleTo(player))
        .map((event) => event.toNarrative())
        .join('\n');
    final teammates = state.werewolves.map((p) => p.name).join(', ');

    return '''
# **战场情报**

## **当前局势**
- **时间**: 第${state.dayNumber}天
- **场上存活**: ${alivePlayers.isNotEmpty ? alivePlayers : '无'}
- **出局玩家**: ${deadPlayers.isNotEmpty ? deadPlayers : '无'}

## **你的身份信息**
- **我的名字**: ${player.name}
- **我的底牌**: ${player.role.name}
- **我的状态**: ${player.isAlive ? '存活' : '已出局，正在观战'}

# **【核心任务简报】**
${player.role.prompt.replaceAll("{teammates}", teammates)}

# **过往回合全记录**
${eventNarratives.isNotEmpty ? eventNarratives : '无'}
''';
  }

  /// 使用JsonCleaner解析JSON响应
  ///
  /// 处理LLM返回的可能包含格式错误的JSON内容
  Future<Map<String, dynamic>> _parseJsonWithCleaner(String content) async {
    try {
      // 首先尝试提取和解析完整的JSON
      final cleanedContent = JsonCleaner.extractJson(content);
      return jsonDecode(cleanedContent);
    } catch (e) {
      try {
        // 如果失败，尝试提取部分JSON
        final partialJson = JsonCleaner.extractPartialJson(content);
        return partialJson ?? {};
      } catch (e) {
        // 最终失败，返回空Map
        return {};
      }
    }
  }
}
