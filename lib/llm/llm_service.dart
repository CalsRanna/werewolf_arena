import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:openai_dart/openai_dart.dart';
import '../game/game_state.dart';
import '../llm/json_cleaner.dart';
import '../player/player.dart';
import '../utils/logger_util.dart';

/// LLM API retry configuration
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 10),
  });
}

/// LLM response
class LLMResponse {
  LLMResponse({
    required this.content,
    required this.parsedData,
    required this.targets,
    required this.statement,
    required this.isValid,
    required this.errors,
    required this.tokensUsed,
    required this.responseTimeMs,
  });

  factory LLMResponse.success({
    required String content,
    Map<String, dynamic> parsedData = const {},
    List<Player> targets = const [],
    String statement = '',
    int tokensUsed = 0,
    int responseTimeMs = 0,
  }) {
    return LLMResponse(
      content: content,
      parsedData: parsedData,
      targets: targets,
      statement: statement,
      isValid: true,
      errors: [],
      tokensUsed: tokensUsed,
      responseTimeMs: responseTimeMs,
    );
  }

  factory LLMResponse.error({
    required String content,
    List<String> errors = const [],
    int tokensUsed = 0,
    int responseTimeMs = 0,
  }) {
    return LLMResponse(
      content: content,
      parsedData: {},
      targets: [],
      statement: '',
      isValid: false,
      errors: errors,
      tokensUsed: tokensUsed,
      responseTimeMs: responseTimeMs,
    );
  }

  final String content;
  final Map<String, dynamic> parsedData;
  final List<Player> targets;
  final String statement;
  final bool isValid;
  final List<String> errors;
  final int tokensUsed;
  final int responseTimeMs;

  @override
  String toString() =>
      'LLMResponse(isValid: $isValid, targets: ${targets.length}, statement: ${statement.isNotEmpty})';
}

/// OpenAI API service using openai_dart package
class OpenAIService {
  OpenAIService({
    required this.apiKey,
    this.model = 'gpt-3.5-turbo',
    OpenAIClient? client,
    this.baseUrl = 'https://api.openai.com/v1',
    this.retryConfig = const RetryConfig(),
  }) : _client = client ??
            OpenAIClient(
              apiKey: apiKey,
              baseUrl: baseUrl,
            );

  final String apiKey;
  final String model;
  final String baseUrl;
  final RetryConfig retryConfig;
  final OpenAIClient _client;

  /// Create service from player model config
  factory OpenAIService.fromPlayerConfig(PlayerModelConfig config) {
    return OpenAIService(
      apiKey: config.apiKey,
      model: config.model,
      baseUrl: config.baseUrl ?? 'https://api.openai.com/v1',
    );
  }

  bool get isAvailable => apiKey.isNotEmpty;

  Future<LLMResponse> generateResponse({
    required String systemPrompt,
    required String userPrompt,
    required Map<String, dynamic> context,
    String? overrideModel,
    String? overrideApiKey,
  }) async {
    final startTime = DateTime.now();
    Exception? lastException;

    for (int attempt = 1; attempt <= retryConfig.maxAttempts; attempt++) {
      try {
        final apiResponse = await _makeChatCompletionRequest(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          context: context,
          overrideModel: overrideModel,
          overrideApiKey: overrideApiKey,
        );

        final responseTimeMs =
            DateTime.now().difference(startTime).inMilliseconds;

        // 如果重试过，记录成功日志
        if (attempt > 1) {
          LoggerUtil.instance.i('LLM API call succeeded on attempt $attempt');
        }

        return LLMResponse.success(
          content: apiResponse['content'],
          parsedData: apiResponse['parsedData'],
          tokensUsed: apiResponse['tokensUsed'],
          responseTimeMs: responseTimeMs,
        );
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        if (attempt == retryConfig.maxAttempts) {
          // 最后一次尝试失败，记录错误日志
          LoggerUtil.instance.e(
              'LLM API call failed after ${retryConfig.maxAttempts} attempts: $lastException');
          break;
        }

        // 记录重试日志
        final delay = _calculateBackoffDelay(attempt);
        LoggerUtil.instance.w(
            'LLM API call failed (attempt $attempt/${retryConfig.maxAttempts}), retrying in ${delay.inMilliseconds}ms: $e');

        // 计算退避延迟时间
        await Future.delayed(delay);
      }
    }

    // 所有重试都失败了
    return LLMResponse.error(
      content:
          'Error after ${retryConfig.maxAttempts} attempts: $lastException',
      errors: [lastException.toString()],
      responseTimeMs: DateTime.now().difference(startTime).inMilliseconds,
    );
  }

  /// 计算指数退避延迟时间
  Duration _calculateBackoffDelay(int attempt) {
    final multiplier = math.pow(retryConfig.backoffMultiplier, attempt - 1);
    final delay = retryConfig.initialDelay * multiplier;
    return Duration(
        milliseconds:
            delay.inMilliseconds.clamp(0, retryConfig.maxDelay.inMilliseconds));
  }

  Future<LLMResponse> generateAction({
    required Player player,
    required GameState state,
    required String rolePrompt,
  }) async {
    // Use player's model config if available, otherwise use defaults
    final effectiveModel = player.modelConfig?.model ?? model;
    final effectiveApiKey = player.modelConfig?.apiKey ?? apiKey;

    final response = await generateResponse(
      systemPrompt: rolePrompt,
      userPrompt: '', // rolePrompt已经包含完整prompt
      context: {'phase': state.currentPhase.name},
      overrideModel: effectiveModel,
      overrideApiKey: effectiveApiKey,
    );

    if (response.isValid) {
      return await _parseActionResponse(response, player, state);
    }

    return response;
  }

  Future<LLMResponse> generateStatement({
    required Player player,
    required GameState state,
    required String context,
    required String prompt,
  }) async {
    final gameContext = _buildContext(player, state);

    // 修改 prompt 要求返回 JSON 格式
    final jsonPrompt = '''
$prompt

请返回 JSON 格式的回复：
{
  "statement": "你的发言内容",
  "reasoning": "你的推理过程（可选）"
}

注意：
1. statement 字段必须包含你的发言内容，语言与提示词一致
2. 直接返回 JSON，不要包含其他格式
3. 发言内容要符合你的角色身份和当前游戏情境

Current game state:
$gameContext

Current situation:
$context
''';

    // Use player's model config if available, otherwise use defaults
    final effectiveModel = player.modelConfig?.model ?? model;
    final effectiveApiKey = player.modelConfig?.apiKey ?? apiKey;

    final response = await generateResponse(
      systemPrompt: '你是一个狼人游戏玩家，请根据提示生成 JSON 格式的回复。',
      userPrompt: jsonPrompt,
      context: {'game_state': gameContext},
      overrideModel: effectiveModel,
      overrideApiKey: effectiveApiKey,
    );

    if (response.isValid) {
      // 解析 JSON 响应
      final parsedData = await _parseJsonResponse(response.content);
      final statement =
          parsedData['statement']?.toString() ?? response.content.trim();

      return LLMResponse.success(
        content: response.content,
        statement: statement,
        parsedData: parsedData,
        responseTimeMs: response.responseTimeMs,
      );
    }

    return response;
  }

  Future<Map<String, dynamic>> _makeChatCompletionRequest({
    required String systemPrompt,
    required String userPrompt,
    required Map<String, dynamic> context,
    String? overrideModel,
    String? overrideApiKey,
  }) async {
    // Use override values if provided, otherwise use defaults
    final effectiveModel = overrideModel ?? model;
    final effectiveApiKey = overrideApiKey ?? apiKey;

    // Use existing client or create new one with different API key
    final client = effectiveApiKey != apiKey
        ? OpenAIClient(apiKey: effectiveApiKey, baseUrl: baseUrl)
        : _client;

    // 构建消息列表
    final messages = <Map<String, String>>[];

    if (userPrompt.isEmpty) {
      // 如果userPrompt为空,将systemPrompt作为用户消息
      messages.add({
        'role': 'user',
        'content': systemPrompt,
      });
    } else {
      // 正常情况：system + user消息
      messages.add({
        'role': 'system',
        'content': systemPrompt,
      });
      messages.add({
        'role': 'user',
        'content': userPrompt,
      });
    }

    try {
      final request = CreateChatCompletionRequest(
        model: ChatCompletionModel.modelId(effectiveModel),
        messages: messages.map((msg) {
          if (msg['role'] == 'system') {
            return ChatCompletionMessage.system(content: msg['content'] ?? '');
          } else {
            return ChatCompletionMessage.user(
                content: ChatCompletionUserMessageContent.string(
                    msg['content'] ?? ''));
          }
        }).toList(),
      );

      // 调试信息：输出请求详情
      LoggerUtil.instance.d(
          'API Request - Model: $effectiveModel, Messages: ${messages.length}');

      final response = await client.createChatCompletion(request: request);

      if (response.choices.isNotEmpty) {
        final message = response.choices.first.message;
        final content = message.content ?? '';
        final tokensUsed = response.usage?.totalTokens ?? 0;

        return {
          'content': content,
          'tokensUsed': tokensUsed,
          'parsedData': <String, dynamic>{},
        };
      } else {
        throw Exception('No choices returned from OpenAI API');
      }
    } on OpenAIClientException catch (e) {
      // 提供更详细的错误信息
      final errorInfo = 'OpenAI API error: ${e.message}';
      if (e.code != null) {
        throw Exception('$errorInfo (Code: ${e.code})');
      }
      throw Exception(errorInfo);
    } catch (e) {
      throw Exception('Unexpected API call error: $e');
    }
  }

  /// 通用 JSON 响应解析方法
  Future<Map<String, dynamic>> _parseJsonResponse(String content) async {
    // Strategy 1: Direct JSON parsing after cleaning
    try {
      final cleanedContent = _extractJsonFromResponse(content);
      return jsonDecode(cleanedContent);
    } catch (e) {
      // Strategy 1 failed, try next
    }

    // Strategy 2: Enhanced JSON cleaner partial extraction
    final partialJson = JsonCleaner.extractPartialJson(content);
    if (partialJson != null) {
      return partialJson;
    }

    // Strategy 3: Return empty JSON if all parsing strategies failed
    return <String, dynamic>{};
  }

  Future<LLMResponse> _parseActionResponse(
    LLMResponse response,
    Player player,
    GameState state,
  ) async {
    final jsonData = await _parseJsonResponse(response.content);

    if (jsonData.isEmpty) {
      return LLMResponse.success(
        content: response.content,
        parsedData: <String, dynamic>{},
        targets: <Player>[],
        statement: '',
        tokensUsed: response.tokensUsed,
        responseTimeMs: response.responseTimeMs,
      );
    }

    // 支持多种target字段名: target_id, target, 目标
    final targetId =
        jsonData['target_id'] ?? jsonData['target'] ?? jsonData['目标'];
    final statement = jsonData['statement'] ?? jsonData['陈述'] ?? '';
    final reasoning = jsonData['reasoning'] ?? jsonData['推理'] ?? '';

    final targets = <Player>[];
    if (targetId != null && targetId.toString().isNotEmpty) {
      // 首先尝试直接通过ID查找
      Player? target = state.getPlayerById(targetId.toString());

      // 如果找不到,尝试通过玩家名字查找(支持"3号玩家"这样的格式)
      if (target == null) {
        final targetStr = targetId.toString();
        for (final p in state.players) {
          if (p.name == targetStr || p.playerId == targetStr) {
            target = p;
            break;
          }
        }
      }

      // 如果还找不到，尝试通过数字匹配玩家名（支持 "5" -> "5号玩家"）
      if (target == null) {
        final targetStr = targetId.toString();
        // 检查是否是纯数字
        final numberMatch = RegExp(r'^\d+$').firstMatch(targetStr);
        if (numberMatch != null) {
          final playerName = '$targetStr号玩家';
          for (final p in state.players) {
            if (p.name == playerName) {
              target = p;
              break;
            }
          }
        }
      }

      if (target != null) {
        targets.add(target);
      }
    }

    // 存储reasoning到parsedData
    final parsedData = Map<String, dynamic>.from(jsonData);
    if (!parsedData.containsKey('reasoning') && reasoning.isNotEmpty) {
      parsedData['reasoning'] = reasoning;
    }

    return LLMResponse.success(
      content: response.content,
      parsedData: parsedData,
      targets: targets,
      statement: statement,
      tokensUsed: response.tokensUsed,
      responseTimeMs: response.responseTimeMs,
    );
  }

  /// Extract JSON from response content, handling markdown formatting and other issues
  String _extractJsonFromResponse(String content) {
    return JsonCleaner.extractJson(content);
  }

  String _buildContext(Player player, GameState state) {
    final alivePlayers = state.alivePlayers.map((p) => p.name).join(', ');
    final deadPlayers = state.deadPlayers.map((p) => p.name).join(', ');

    return '''
Game Day ${state.dayNumber}
Current phase: ${state.currentPhase.displayName}
Alive players: ${alivePlayers.isNotEmpty ? alivePlayers : 'None'}
Dead players: ${deadPlayers.isNotEmpty ? deadPlayers : 'None'}
Your status: ${player.isAlive ? 'Alive' : 'Dead'}
Your role: ${player.role.name}
''';
  }

  void dispose() {
    // OpenAIClient doesn't need explicit disposal
  }
}
