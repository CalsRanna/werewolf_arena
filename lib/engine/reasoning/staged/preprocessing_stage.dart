import 'dart:convert';

import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/game_logger.dart';
import 'package:werewolf_arena/engine/player/ai_player.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 阶段一：信息预处理
///
/// 使用Fast Model将游戏历史和状态整理成结构化的WorldState
/// 结果存储在ReasoningContext.worldState中
class PreprocessingStage {
  final OpenAIClient client;
  final String fastModelId;
  static const int maxRetries = 3;

  PreprocessingStage({
    required this.client,
    required this.fastModelId,
  });

  /// 执行预处理
  Future<void> execute(ReasoningContext context) async {
    GameLogger.instance.d('[预处理阶段] 开始...');

    final systemPrompt = _buildSystemPrompt();
    final userPrompt = _buildUserPrompt(context.player, context.state, context.skill);

    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 1) {
          GameLogger.instance
              .d('[预处理阶段] 重试第 $attempt/$maxRetries 次...');
          // 指数退避
          await Future.delayed(Duration(seconds: attempt * 2));
        }

        final response = await client.createChatCompletion(
          request: CreateChatCompletionRequest(
            model: ChatCompletionModel.modelId(fastModelId),
            messages: [
              ChatCompletionMessage.system(content: systemPrompt),
              ChatCompletionMessage.user(
                content: ChatCompletionUserMessageContent.string(userPrompt),
              ),
            ],
            temperature: 0.3, // 预处理需要稳定性，不需要创造性
          ),
        );

        final content = response.choices.first.message.content ?? '';
        final jsonStr = content.trim();

        // 解析JSON
        final Map<String, dynamic> jsonData;
        try {
          jsonData = _parseJson(jsonStr);
        } catch (e) {
          GameLogger.instance
              .e('[预处理阶段] JSON解析失败: $e\n原始内容: $jsonStr');
          lastException = e as Exception;
          continue; // 重试
        }

        // 将WorldState存储到context中
        context.worldState = WorldState.fromJson(jsonData);

        GameLogger.instance.d('[预处理阶段] 完成');
        return;
      } on OpenAIClientException catch (e) {
        lastException = e;
        // 429 rate limit 或 5xx 服务器错误，重试
        if (e.code == 429 || (e.code ?? 0) >= 500) {
          GameLogger.instance.w('[预处理阶段] API错误 ${e.code}，准备重试...');
          continue;
        } else {
          // 其他错误直接抛出
          rethrow;
        }
      } catch (e, stackTrace) {
        lastException = e as Exception;
        GameLogger.instance.e('[预处理阶段] 失败: $e\n$stackTrace');
        if (attempt == maxRetries) {
          rethrow;
        }
      }
    }

    // 所有重试都失败了
    throw lastException ?? Exception('预处理阶段失败：未知错误');
  }

  String _buildSystemPrompt() {
    return '''
你是狼人杀游戏的数据分析助手。你的任务是将非结构化的游戏信息整理成结构化的JSON数据。

# 任务
1. 提取关键事实和事件
2. 分析社交关系（谁信任谁，谁怀疑谁）
3. 总结当前局势
4. 识别核心矛盾

# 输出要求
- **严格的纯JSON格式**，无任何注释或Markdown标记
- **JSON必须完全有效**，注意：
  * 所有字符串值必须用双引号包裹
  * 布尔值用true/false（无引号）
  * 数字无引号
  * 检查是否有多余的引号或逗号
- 客观、准确、结构化
- 不需要推理和策略，只需要整理事实

# 重要：JSON格式检查清单
✓ 每个key后面是冒号，不是等号
✓ 字符串值两侧都有且只有一对双引号
✓ 布尔值是 true 或 false，不是 "true" 或 "false"
✓ 数组最后一个元素后没有逗号
✓ 对象最后一个属性后没有逗号
''';
  }

  String _buildUserPrompt(
    GamePlayer player,
    GameContext state,
    GameSkill skill,
  ) {
    final playerNumber = player.name.replaceAll('号玩家', '');

    // 获取玩家的WorkingMemory（如果有）
    final workingMemory = player is AIPlayer ? player.workingMemory : null;

    // 构建秘密知识
    final secretKnowledge = <String, dynamic>{};
    if (workingMemory != null) {
      final secret = workingMemory.secretKnowledge;
      if (secret.inspectionResults.isNotEmpty) {
        secretKnowledge['inspection_results'] = secret.inspectionResults;
      }
      if (secret.protectionHistory.isNotEmpty) {
        secretKnowledge['protection_history'] = secret.protectionHistory;
      }
      secretKnowledge.addAll(secret.otherSecrets);
    }

    // 构建队友列表
    final teammates = <String>[];
    if (player.role.id == 'werewolf') {
      teammates.addAll(
        state.players
            .where((p) => p.role.id == 'werewolf' && p.id != player.id)
            .map((p) => p.name),
      );
    }

    // 构建游戏历史摘要
    final alivePlayers = state.alivePlayers.map((p) => p.name).toList();
    final deadPlayers = state.deadPlayers.map((p) => p.name).toList();

    // *** 新增：提取游戏事件历史 ***
    final gameHistory = _buildGameHistory(state, player);

    // *** 新增：提取历史发言 ***
    final speechHistory = _buildSpeechHistory(state);

    return '''
# 游戏信息

**我的身份**
- 名称: ${player.name}
- 号码: $playerNumber
- 角色: ${player.role.name}
- 阵营: ${player.role.id == 'werewolf' ? '狼人' : '好人'}
${teammates.isNotEmpty ? '- 队友: ${teammates.join(", ")}' : ''}

**当前局势**
- 第${state.day}天
- 当前阶段: ${skill.name}
- 存活玩家 (${alivePlayers.length}人): ${alivePlayers.join(", ")}
- 出局玩家 (${deadPlayers.length}人): ${deadPlayers.isEmpty ? '无' : deadPlayers.join(", ")}

${gameHistory.isNotEmpty ? '''
**游戏历史**
$gameHistory
''' : ''}

${speechHistory.isNotEmpty ? '''
**历史发言摘要**
$speechHistory
''' : ''}

${workingMemory != null ? '''
**我的历史记忆**
${workingMemory.toPromptText()}
''' : ''}

---

# 任务：整理为结构化JSON

请将上述信息整理成以下JSON格式：

```json
{
  "self_info": {
    "name": "玩家名称",
    "number": "号码",
    "role": "角色",
    "faction": "阵营",
    "teammates": ["队友1", "队友2"],
    "secret_knowledge": {}
  },
  "other_players": [
    {
      "name": "其他玩家名",
      "is_alive": true,
      "estimated_role": "推测角色(基于历史行为推断，可选)",
      "estimated_confidence": 50,
      "key_speech_summary": ["该玩家的关键发言摘要"]
    }
  ],
  "key_events": [
    {
      "description": "关键事件描述（如：X号被刀、Y号起跳预言家等）",
      "importance": 80,
      "timestamp": "第X天Y阶段"
    }
  ],
  "social_relationships": {
    "alliances": {
      "玩家A": ["玩家B", "玩家C"]
    },
    "hostilities": {
      "玩家X": ["玩家Y"]
    },
    "my_most_trusted": ["最信任的玩家"],
    "my_most_suspicious": ["最怀疑的玩家"]
  },
  "situation_summary": "当前局势一句话总结",
  "core_conflict": "核心矛盾(可选)"
}
```
''';
  }

  /// 构建游戏历史文本
  String _buildGameHistory(GameContext state, GamePlayer player) {
    GameLogger.instance.d('[预处理阶段] 可见事件数量: ${state.visibleEvents.length}');

    if (state.visibleEvents.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    final recentEvents = state.visibleEvents.take(20).toList(); // 最近20个事件

    for (final event in recentEvents) {
      final formatted = _formatEvent(event);
      GameLogger.instance.d('[预处理阶段] 事件: $formatted');
      buffer.writeln('- $formatted');
    }

    final result = buffer.toString();
    GameLogger.instance.d('[预处理阶段] 游戏历史长度: ${result.length} 字符');
    return result;
  }

  /// 格式化事件描述
  String _formatEvent(GameEvent event) {
    // 根据事件类型格式化输出
    return '[第${event.day}天] ${event.toString()}';
  }

  /// 构建历史发言摘要
  String _buildSpeechHistory(GameContext state) {
    // 从事件中提取发言类事件（Discuss, Conspire等）
    // 这里可以进一步优化，提取DiscussEvent等发言事件
    // 暂时简化处理
    return '';
  }

  Map<String, dynamic> _parseJson(String jsonStr) {
    // 移除可能的markdown标记
    var cleaned = jsonStr.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    }
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    // 尝试修复常见的JSON格式错误
    cleaned = _fixCommonJsonErrors(cleaned);

    // 解析JSON
    return jsonDecode(cleaned) as Map<String, dynamic>;
  }

  /// 修复常见的JSON格式错误
  String _fixCommonJsonErrors(String json) {
    // 修复 "is_alive":true" 这种错误（值后面多了引号）
    json = json.replaceAllMapped(
      RegExp(r':true"'),
      (match) => ':true',
    );
    json = json.replaceAllMapped(
      RegExp(r':false"'),
      (match) => ':false',
    );

    // 修复 "value":"" 后面多引号的问题
    json = json.replaceAllMapped(
      RegExp(r':"([^"]*)"([,}\]])'),
      (match) => ':"${match.group(1)}"${match.group(2)}',
    );

    return json;
  }
}
