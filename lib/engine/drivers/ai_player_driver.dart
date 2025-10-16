import 'dart:convert';
import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_config.dart';
import 'package:werewolf_arena/engine/drivers/player_driver.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/drivers/llm_service.dart';
import 'package:werewolf_arena/engine/drivers/json_cleaner.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/werewolf_discuss_skill.dart';

/// AI玩家驱动器
///
/// 使用LLM为AI玩家生成决策的驱动器实现
class AIPlayerDriver implements PlayerDriver {
  /// 玩家智能配置
  final PlayerIntelligence intelligence;

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
2.  **人性化表达**：你的发言应该充满个人风格、情绪和目的性。你可以表现出愤怒、伪装无辜、煽动情绪、安抚同伴。使用更口语化、更具感染力的语言，而不是干巴巴地陈述逻辑。
3.  **构建叙事，而非罗列信息**：不要仅仅陈述“A做了B，所以我怀疑A”。要将零散的信息（事件历史、玩家投票、发言）串联成一个有说服力的故事，构建你的逻辑链，引导其他玩家的思维。例如：“3号玩家昨天说要保4号，今天却第一个投票给4号，他的行为逻辑已经完全崩塌了，在我这里他就是一张必出的狼人牌。”
4.  **善用高级战术**：逻辑分析只是基础。心理博弈、话术陷阱、建立同盟、制造对立、悍跳（狼人跳预言家）、倒钩（狼人站队真预言家卖队友）、冲锋（狼人抱团攻击一个好人）... 这些都是你信手拈来的武器。根据你的角色和场上局势，灵活运用。
5.  **拥有记忆和立场**：你必须记住之前的回合发生了什么，谁说了什么，谁投了谁。你的每一次发言和决策都必须基于这些记忆，并服务于你当前阵营的立场。保持你人设和逻辑的一致性，除非你在进行战术伪装。

现在，游戏开始。阅读我提供给你的游戏情境，代入你的角色，做出最有利于你阵营的决策。
''';

  /// 构造函数
  ///
  /// [intelligence] 玩家的AI配置，包含API密钥、模型ID等信息
  AIPlayerDriver({required this.intelligence})
    : _service = OpenAIService(
        baseUrl: intelligence.baseUrl,
        apiKey: intelligence.apiKey,
        model: intelligence.modelId,
        retryConfig: const RetryConfig(maxAttempts: 3),
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
${_buildGameContext(player, state)}
${(state.dayNumber == 1 && skill is WerewolfDiscussSkill) ? skill.firstNightPrompt : skill.prompt}
${PlayerDriverResponse.formatPrompt}
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
- **时间**: 第${state.dayNumber}天，${state.currentPhase.displayName}
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
