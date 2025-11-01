/// 推理结果
///
/// 封装推理引擎的最终输出
class ReasoningResult {
  /// 公开发言
  final String? message;

  /// 完整的思考链
  final String reasoning;

  /// 目标玩家
  final String? target;

  /// 元数据（用于调试和分析）
  final Map<String, dynamic> metadata;

  const ReasoningResult({
    this.message,
    required this.reasoning,
    this.target,
    this.metadata = const {},
  });

  /// 转换为PlayerDriverResponse格式
  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'reasoning': reasoning,
      'target': target,
    };
  }

  /// 获取调试信息
  String getDebugInfo() {
    final buffer = StringBuffer();
    buffer.writeln('=== 推理结果 ===');
    buffer.writeln('发言: $message');
    buffer.writeln('目标: $target');
    buffer.writeln('\n=== 完整思考链 ===');
    buffer.writeln(reasoning);
    buffer.writeln('\n=== 元数据 ===');
    metadata.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    return buffer.toString();
  }
}
