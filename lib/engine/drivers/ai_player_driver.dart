import 'dart:convert';
import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_config.dart';
import 'package:werewolf_arena/engine/drivers/player_driver.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/drivers/llm_service.dart';
import 'package:werewolf_arena/engine/drivers/json_cleaner.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';

/// AI玩家驱动器
///
/// 使用LLM为AI玩家生成决策的驱动器实现
class AIPlayerDriver implements PlayerDriver {
  /// 玩家智能配置
  final PlayerIntelligence intelligence;

  /// OpenAI服务实例
  final OpenAIService _service;

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
${skill.prompt}

${PlayerDriverResponse.formatPrompt}

注意：
1. 直接返回JSON，不要包含其他格式
2. 确保数据格式正确
3. 根据你的角色身份和当前游戏情境做出决策

${_buildGameContext(player, state)}
''';

    try {
      // 调用LLM服务生成响应
      final response = await _service.generateResponse(
        systemPrompt:
            '你是狼人杀游戏中的骨灰级玩家，你的终极任务是帮助你的阵营赢得游戏胜利，为此你可以使用任何手段和战术，但不能盘场外。',
        userPrompt: userPrompt,
        context: {
          'phase': state.currentPhase.name,
          'day': state.dayNumber,
          'player_role': player.role.name,
        },
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
    final playerName = player?.name ?? 'Unknown';
    final playerRole = player?.role?.name ?? 'Unknown';
    final isAlive = player?.isAlive ?? false;
    final visibleEvents = state.events
        .where((event) => event.isVisibleTo(player))
        .toList();
    print(visibleEvents.map((event) => event.toString()).join(', '));
    return '''
游戏状态：
- 第${state.dayNumber}天
- 当前阶段：${state.currentPhase.displayName}
- 存活玩家：${alivePlayers.isNotEmpty ? alivePlayers : '无'}
- 死亡玩家：${deadPlayers.isNotEmpty ? deadPlayers : '无'}
- 你的状态：${isAlive ? '存活' : '死亡'}
- 你的角色：$playerRole
- 你的名字：$playerName,

事件历史：
${visibleEvents.map((event) => event.toJson()).join('\n')}
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
