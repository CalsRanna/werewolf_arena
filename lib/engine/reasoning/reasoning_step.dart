import 'package:openai_dart/openai_dart.dart';
import 'package:werewolf_arena/engine/reasoning/reasoning_context.dart';

/// 推理步骤抽象类
///
/// 代表多步推理链中的一个步骤
/// 每个步骤接收上下文，执行特定的推理任务，并更新上下文
abstract class ReasoningStep {
  /// 步骤名称
  String get name;

  /// 步骤描述
  String get description;

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

  /// 是否应该跳过此步骤
  ///
  /// 某些步骤在特定条件下可以跳过以节省时间
  bool shouldSkip(ReasoningContext context) => false;

  /// 构建此步骤的Prompt
  ///
  /// 可选方法，用于生成此步骤的LLM提示词
  String? buildPrompt(ReasoningContext context) => null;

  /// 解析LLM响应
  ///
  /// 可选方法，用于解析LLM返回的结果
  dynamic parseResponse(String response) => response;
}
