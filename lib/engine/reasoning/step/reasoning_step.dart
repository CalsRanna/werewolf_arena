import 'dart:convert';
import 'dart:math' as math;

import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/game_engine_logger.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';

/// 推理步骤抽象类
///
/// 代表多步推理链中的一个步骤
/// 每个步骤接收上下文，执行特定的推理任务，并更新上下文
abstract class ReasoningStep {
  /// 步骤描述
  String get description;

  /// 最大重试次数（子类可重写）
  int get maxRetries => 10;

  /// 步骤名称
  String get name;

  /// 构建此步骤的Prompt
  ///
  /// 可选方法，用于生成此步骤的LLM提示词
  String? buildPrompt(ReasoningContext context) => null;

  /// 执行推理步骤
  ///
  /// [context] 当前推理上下文，包含前面步骤的所有输出
  /// [client] OpenAI客户端，用于调用LLM API
  ///
  /// 返回更新后的上下文
  Future<ReasoningContext> execute(
    ReasoningContext context,
    OpenAIClient client,
  );

  /// 带重试的LLM调用（通用方法）
  ///
  /// [client] OpenAI客户端
  /// [modelId] 模型ID
  /// [systemPrompt] 系统提示词
  /// [userPrompt] 用户提示词
  /// [context] 推理上下文（用于记录token）
  /// [validator] 可选的响应验证器，验证失败会触发重试
  ///
  /// 返回LLM响应内容
  Future<Map<String, dynamic>> request({
    required OpenAIClient client,
    required String modelId,
    required String systemPrompt,
    required String userPrompt,
    required ReasoningContext context,
    bool Function(String response)? validator,
  }) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // 构建消息
        final messages = <ChatCompletionMessage>[
          ChatCompletionMessage.system(content: systemPrompt),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(userPrompt),
          ),
        ];

        // 创建请求
        final request = CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId(modelId),
          messages: messages,
        );

        // 调用LLM API
        final response = await client.createChatCompletion(request: request);

        // 检查响应
        if (response.choices.isEmpty) {
          throw Exception('LLM响应为空（response.choices.isEmpty）');
        }

        final content = response.choices.first.message.content ?? '';

        // 如果提供了验证器，验证响应
        if (validator != null && !validator(content)) {
          throw Exception('LLM响应验证失败');
        }

        // 记录token使用量
        final tokensUsed = response.usage?.totalTokens ?? 0;
        context.recordStepTokens(name, tokensUsed);
        return _parse(content);
      } on OpenAIClientException catch (e) {
        final errorInfo = 'OpenAI API错误: ${e.message}';
        lastException = Exception(
          e.code != null ? '$errorInfo (Code: ${e.code})' : errorInfo,
        );
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
      }

      // 如果不是最后一次尝试，等待后重试
      if (attempt < maxRetries) {
        final delay = _calculateBackoffDelay(attempt);
        GameEngineLogger.instance.w(
          '[$name] LLM调用失败 ($attempt/$maxRetries)，${delay.inSeconds}s后重试: $lastException',
        );
        await Future.delayed(delay);
      }
    }

    // 所有重试都失败了
    final errorMsg = '[$name] LLM调用失败（已重试$maxRetries次）: $lastException';
    GameEngineLogger.instance.e(errorMsg);
    throw Exception(errorMsg);
  }

  /// 是否应该跳过此步骤
  ///
  /// 某些步骤在特定条件下可以跳过以节省时间
  bool shouldSkip(ReasoningContext context) => false;

  /// 计算退避延迟（指数退避策略）
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

  Map<String, dynamic> _parse(String response) {
    // 提取JSON（去除markdown代码块）
    String jsonStr = response.trim();
    if (jsonStr.contains('```json')) {
      final start = jsonStr.indexOf('```json') + 7;
      final end = jsonStr.lastIndexOf('```');
      jsonStr = jsonStr.substring(start, end).trim();
    } else if (jsonStr.contains('```')) {
      final start = jsonStr.indexOf('```') + 3;
      final end = jsonStr.lastIndexOf('```');
      jsonStr = jsonStr.substring(start, end).trim();
    }
    return jsonDecode(jsonStr);
  }
}
