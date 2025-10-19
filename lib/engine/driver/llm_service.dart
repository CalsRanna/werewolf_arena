import 'dart:async';
import 'dart:math' as math;
import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';

/// LLM API retry configuration
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;

  const RetryConfig({
    this.maxAttempts = 10,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
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
    List<GamePlayer> targets = const [],
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
  final List<GamePlayer> targets;
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
  }) : _client =
           client ??
           OpenAIClient(
             apiKey: apiKey,
             baseUrl: baseUrl,
             headers: {
               'HTTP-Referer': 'https://github.com/CalsRanna/werewolf_arena',
               'X-Title': 'Werewolf Arena',
             },
           );

  final String apiKey;
  final String model;
  final String baseUrl;
  final RetryConfig retryConfig;
  final OpenAIClient _client;

  bool get isAvailable => apiKey.isNotEmpty;

  Future<LLMResponse> generateResponse({
    required String systemPrompt,
    required String userPrompt,
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
          overrideModel: overrideModel,
          overrideApiKey: overrideApiKey,
        );

        final responseTimeMs = DateTime.now()
            .difference(startTime)
            .inMilliseconds;

        // 如果重试过，记录成功日志
        if (attempt > 1) {
          GameEngineLogger.instance.d(
            'LLM API call succeeded on attempt $attempt',
          );
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
          GameEngineLogger.instance.e(
            '$e, attempts $attempt/${retryConfig.maxAttempts}',
          );
          break;
        }

        // 记录重试日志
        final delay = _calculateBackoffDelay(attempt);
        GameEngineLogger.instance.w(
          '$e, attempt $attempt/${retryConfig.maxAttempts}',
        );

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
  ///
  /// 使用改进的指数退避算法，避免延迟时间增长过快：
  /// - 使用 min(maxDelay, initialDelay * multiplier^attempt) 来限制增长
  /// - 添加抖动（jitter）来避免雷鸣羊群效应
  Duration _calculateBackoffDelay(int attempt) {
    // 计算基础延迟，使用 attempt 而不是 attempt - 1，这样第一次重试就有延迟
    final baseDelayMs =
        retryConfig.initialDelay.inMilliseconds *
        math.pow(retryConfig.backoffMultiplier, attempt - 1);

    // 限制最大延迟时间
    final cappedDelayMs = math.min(
      baseDelayMs.toDouble(),
      retryConfig.maxDelay.inMilliseconds.toDouble(),
    );

    // 添加随机抖动（0.5 ~ 1.0 倍的延迟），避免所有请求同时重试
    final jitter = 0.5 + math.Random().nextDouble() * 0.5;
    final finalDelayMs = (cappedDelayMs * jitter).toInt();

    return Duration(milliseconds: finalDelayMs);
  }

  Future<Map<String, dynamic>> _makeChatCompletionRequest({
    required String systemPrompt,
    required String userPrompt,
    String? overrideModel,
    String? overrideApiKey,
  }) async {
    // Use override values if provided, otherwise use defaults
    final effectiveModel = overrideModel ?? model;
    final effectiveApiKey = overrideApiKey ?? apiKey;

    // Use existing client or create new one with different API key
    var headers = {
      'HTTP-Referer': 'https://github.com/CalsRanna/werewolf_arena',
      'X-Title': 'Werewolf Arena',
    };
    final client = effectiveApiKey != apiKey
        ? OpenAIClient(
            apiKey: effectiveApiKey,
            baseUrl: baseUrl,
            headers: headers,
          )
        : _client;

    // 构建消息列表
    final messages = <Map<String, String>>[];

    if (userPrompt.isEmpty) {
      // 如果userPrompt为空,将systemPrompt作为用户消息
      messages.add({'role': 'user', 'content': systemPrompt});
    } else {
      // 正常情况：system + user消息
      messages.add({'role': 'system', 'content': systemPrompt});
      messages.add({'role': 'user', 'content': userPrompt});
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
                msg['content'] ?? '',
              ),
            );
          }
        }).toList(),
      );

      final response = await client.createChatCompletion(request: request);

      if (response.choices.isNotEmpty) {
        final message = response.choices.first.message;
        final content = message.content ?? '';
        final tokensUsed = response.usage?.totalTokens ?? 0;
        GameEngineLogger.instance.d(content);
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
}
