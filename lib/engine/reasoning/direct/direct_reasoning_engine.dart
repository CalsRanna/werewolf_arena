import 'dart:convert';

import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/game_logger.dart';
import 'package:werewolf_arena/engine/player/ai_player.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/reasoning/memory/working_memory.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_result.dart';
import 'package:werewolf_arena/engine/skill/conspire_skill.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 直接推理引擎
///
/// 使用单次LLM调用完成所有推理，无预处理和后处理
/// 最快速的决策方式，适合快速决策场景
class DirectReasoningEngine {
  final OpenAIClient client;
  final String modelId;
  final bool enableVerboseLogging;
  static const int maxRetries = 3;

  DirectReasoningEngine({
    required this.client,
    required this.modelId,
    this.enableVerboseLogging = true,
  });

  /// 执行直接推理
  Future<ReasoningResult> execute({
    required GamePlayer player,
    required GameContext state,
    required GameSkill skill,
  }) async {
    final startTime = DateTime.now();

    _log('=' * 60);
    _log('开始单步推理: ${player.name} (${player.role.name}) - ${skill.name}');
    _log('=' * 60);

    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 1) {
          _log('重试第 $attempt/$maxRetries 次...');
          // 指数退避
          await Future.delayed(Duration(seconds: attempt * 2));
        }

        final systemPrompt = _buildSystemPrompt(player, state);
        final userPrompt = _buildUserPrompt(player, state, skill);

        final response = await client.createChatCompletion(
          request: CreateChatCompletionRequest(
            model: ChatCompletionModel.modelId(modelId),
            messages: [
              ChatCompletionMessage.system(content: systemPrompt),
              ChatCompletionMessage.user(
                content: ChatCompletionUserMessageContent.string(userPrompt),
              ),
            ],
            temperature: 0.7,
          ),
        );

        final content = response.choices.first.message.content ?? '';
        final jsonStr = content.trim();

        // 解析JSON
        final Map<String, dynamic> jsonData;
        try {
          jsonData = _parseJson(jsonStr);
        } catch (e) {
          _logError('JSON解析失败: $e\n原始内容: $jsonStr');
          lastException = e as Exception;
          continue; // 重试
        }

        final reasoning = jsonData['analysis'] as String? ?? '';
        final speech = jsonData['speech'] as String?;
        final target = jsonData['target'] as String?;
        final memoryUpdate = jsonData['memory_update'] as Map<String, dynamic>?;

        // 更新WorkingMemory
        if (player is AIPlayer && memoryUpdate != null) {
          _updatePlayerMemory(player, memoryUpdate);
        }

        final endTime = DateTime.now();
        final totalDuration = endTime.difference(startTime);

        _log('推理完成，总耗时: ${totalDuration.inMilliseconds}ms');
        _log('=' * 60);

        return ReasoningResult(
          message: speech,
          reasoning: reasoning,
          target: target,
          metadata: {
            'start_time': startTime.toIso8601String(),
            'end_time': endTime.toIso8601String(),
            'total_duration_ms': totalDuration.inMilliseconds,
            'engine_type': 'direct',
            'retries': attempt - 1,
          },
        );
      } on OpenAIClientException catch (e) {
        lastException = e;
        // 429 rate limit 或 5xx 服务器错误，重试
        if (e.code == 429 || (e.code ?? 0) >= 500) {
          _log('API错误 ${e.code}，准备重试...');
          continue;
        } else {
          // 其他错误直接抛出
          rethrow;
        }
      } catch (e, stackTrace) {
        lastException = e as Exception;
        _logError('推理失败: $e\n$stackTrace');
        if (attempt == maxRetries) {
          rethrow;
        }
      }
    }

    // 所有重试都失败了
    throw lastException ?? Exception('单步推理失败：未知错误');
  }

  String _buildSystemPrompt(GamePlayer player, GameContext state) {
    final playerNumber = player.name.replaceAll('号玩家', '');

    // 构建队友列表
    final teammates = <String>[];
    if (player.role.id == 'werewolf') {
      teammates.addAll(
        state.players
            .where((p) => p.role.id == 'werewolf' && p.id != player.id)
            .map((p) => p.name),
      );
    }

    return '''
你是一名真实的狼人杀玩家，不是AI。

# 身份认知【核心】
- 你是${player.name}（$playerNumber号玩家）
- 当其他人提到"$playerNumber号"、"$playerNumber"时，他们说的就是你
- 你的真实身份是${player.role.name}，阵营是${player.role.id == 'werewolf' ? '狼人' : '好人'}
${teammates.isNotEmpty ? '- 你的队友是：${teammates.join(", ")}' : ''}

# 唯一目标
不惜一切代价，带领你的${player.role.id == 'werewolf' ? '狼人' : '好人'}阵营走向胜利。

# 核心准则

1. **彻底沉浸**：用"我"思考和发言。严禁提及AI、提示词或游戏外内容。

2. **区分内心与发言【铁律】**：
   - **内心思考(analysis字段)**：可用所有秘密信息(底牌/队友/查验结果)进行深度分析
   - **公开发言(speech字段)**：绝对不能直接暴露秘密信息
   - **表达方式**：利用秘密信息解读公开信息，构建对你阵营有利的"故事"

3. **自我认知**：时刻记住你是$playerNumber号，不要在分析中把自己当成别人

4. **遵守技能要求**：严格按照技能提示的要求输出，不要自行扩展

记住：你拥有完整的自主权，可以自由发挥你的智慧。
''';
  }

  String _buildUserPrompt(
    GamePlayer player,
    GameContext state,
    GameSkill skill,
  ) {
    final playerNumber = player.name.replaceAll('号玩家', '');

    // 获取玩家的WorkingMemory
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

    // 构建游戏历史
    final alivePlayers = state.alivePlayers.map((p) => p.name).toList();
    final deadPlayers = state.deadPlayers.map((p) => p.name).toList();
    final gameHistory = _buildGameHistory(state, player);

    // 技能提示
    final skillPrompt = (state.day == 1 && skill is ConspireSkill)
        ? skill.firstNightPrompt
        : skill.prompt;

    // 格式提示
    final formatPrompt = skill is ConspireSkill
        ? _getConspireFormatPrompt()
        : _getStandardFormatPrompt();

    return '''
${state.scenario.rule}

---

# 游戏信息

**我的身份**
- 名称: ${player.name}
- 号码: $playerNumber
- 角色: ${player.role.name}
- 阵营: ${player.role.id == 'werewolf' ? '狼人' : '好人'}
${teammates.isNotEmpty ? '- 队友: ${teammates.join(", ")}' : ''}
${secretKnowledge.isNotEmpty ? '- 秘密信息: ${jsonEncode(secretKnowledge)}' : ''}

**当前局势**
- 第${state.day}天
- 当前阶段: ${skill.name}
- 存活玩家 (${alivePlayers.length}人): ${alivePlayers.join(", ")}
- 出局玩家 (${deadPlayers.length}人): ${deadPlayers.isEmpty ? '无' : deadPlayers.join(", ")}

${gameHistory.isNotEmpty ? '''
**游戏历史**
$gameHistory
''' : ''}

${workingMemory != null ? '''
**我的历史记忆**
${workingMemory.toPromptText()}
''' : ''}

---

$skillPrompt

---

$formatPrompt
''';
  }

  String _buildGameHistory(GameContext state, GamePlayer player) {
    if (state.visibleEvents.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    final recentEvents = state.visibleEvents.take(30).toList();

    for (final event in recentEvents) {
      buffer.writeln('- ${_formatEvent(event)}');
    }

    return buffer.toString();
  }

  String _formatEvent(GameEvent event) {
    return '[第${event.day}天] ${event.toString()}';
  }

  String _getStandardFormatPrompt() {
    return '''
# 你的决策输出

**重要提醒**：请严格遵守上述技能提示中的输出要求。如果技能提示要求简短回复（如"上警"/"不上警"），请不要自行扩展。

请以纯JSON格式输出（无注释，无Markdown标记）：

{
  "analysis": "你的完整内心分析过程",
  "strategy": "你的本回合策略（1-2句话）",
  "speech": "你的公开发言（无需发言则null）。注意：如果技能要求简短回复，请严格遵守",
  "target": "目标玩家名（如'3号玩家'，无目标则null）",
  "memory_update": {
    "identity_inference": {
      "玩家名": {
        "estimated_role": "推测角色",
        "confidence": 70,
        "reasoning": "推理依据"
      }
    },
    "key_facts": [
      {
        "description": "关键事实",
        "importance": 80,
        "day": 1
      }
    ],
    "core_conflict": "核心矛盾",
    "focus_players": ["重点关注的玩家"]
  }
}
''';
  }

  String _getConspireFormatPrompt() {
    return '''
# 你的决策输出（狼人密谈专用）

在狼人密谈环节，speech字段的含义改为"对狼队友的发言"。

请以纯JSON格式输出：

{
  "analysis": "你的完整内心分析",
  "strategy": "你建议的狼队策略",
  "speech": "你对狼队友的发言",
  "target": "你建议的袭击目标玩家名"
}
''';
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

  String _fixCommonJsonErrors(String json) {
    // 修复布尔值后面多引号
    json = json.replaceAllMapped(RegExp(r':true"'), (match) => ':true');
    json = json.replaceAllMapped(RegExp(r':false"'), (match) => ':false');
    json = json.replaceAllMapped(RegExp(r':null"'), (match) => ':null');

    return json;
  }

  void _updatePlayerMemory(AIPlayer player, Map<String, dynamic> memoryUpdate) {
    try {
      // 获取或创建 WorkingMemory
      var memory = player.workingMemory;
      memory ??= WorkingMemory(
        secretKnowledge: SecretKnowledge(
          myRole: player.role.name,
          teammates: player.role.id == 'werewolf'
              ? player.metadata['teammates'] as List<String>? ?? []
              : [],
        ),
      );

      // 更新身份推测
      final identityInference =
          memoryUpdate['identity_inference'] as Map<String, dynamic>?;
      if (identityInference != null) {
        identityInference.forEach((playerName, data) {
          if (data is Map<String, dynamic>) {
            memory!.updateIdentityEstimate(
              playerName,
              IdentityEstimate(
                estimatedRole: data['estimated_role'] as String? ?? '未知',
                confidence: (data['confidence'] as num?)?.toInt() ?? 0,
                reasoning: data['reasoning'] as String? ?? '',
              ),
            );
          }
        });
      }

      // 更新关键事实
      final keyFacts = memoryUpdate['key_facts'] as List?;
      if (keyFacts != null) {
        for (var fact in keyFacts) {
          if (fact is Map<String, dynamic>) {
            memory.addKeyFact(
              KeyFact(
                description: fact['description'] as String? ?? '',
                importance: (fact['importance'] as num?)?.toInt() ?? 50,
                day: fact['day'] as int? ?? 1,
              ),
            );
          }
        }
      }

      // 更新核心矛盾
      final coreConflict = memoryUpdate['core_conflict'] as String?;
      if (coreConflict != null && coreConflict.isNotEmpty) {
        memory.coreConflict = coreConflict;
      }

      // 更新重点关注玩家
      final focusPlayers = memoryUpdate['focus_players'] as List?;
      if (focusPlayers != null) {
        memory.setFocusPlayers(focusPlayers.cast<String>());
      }

      // 保存更新后的记忆
      player.workingMemory = memory;

      _log(
        'WorkingMemory更新完成 - 身份推测: ${memory.identityEstimates.length}个, '
        '关键事实: ${memory.keyFacts.length}个',
      );
    } catch (e) {
      _logError('WorkingMemory更新失败: $e');
    }
  }

  void _log(String message) {
    if (enableVerboseLogging) {
      GameLogger.instance.d('[直接推理引擎] $message');
    }
  }

  void _logError(String message) {
    GameLogger.instance.e('[直接推理引擎] $message');
  }
}
