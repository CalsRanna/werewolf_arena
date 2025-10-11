/// 游戏引擎日志级别
enum GameLogLevel { debug, info, warning, error }

/// 游戏引擎内部日志事件
///
/// 这是游戏引擎向外部暴露内部运行状态的机制
/// 外部观察者可以选择如何处理这些日志（输出到文件、控制台、UI等）
class GameLogEvent {
  /// 日志级别
  final GameLogLevel level;

  /// 日志消息
  final String message;

  /// 时间戳
  final DateTime timestamp;

  const GameLogEvent({
    required this.level,
    required this.message,
    required this.timestamp,
  });

  /// 创建调试日志
  factory GameLogEvent.debug(String message) {
    return GameLogEvent(
      level: GameLogLevel.debug,
      message: message,
      timestamp: DateTime.now(),
    );
  }

  /// 创建信息日志
  factory GameLogEvent.info(String message) {
    return GameLogEvent(
      level: GameLogLevel.info,
      message: message,
      timestamp: DateTime.now(),
    );
  }

  /// 创建警告日志
  factory GameLogEvent.warning(String message) {
    return GameLogEvent(
      level: GameLogLevel.warning,
      message: message,
      timestamp: DateTime.now(),
    );
  }

  /// 创建错误日志
  factory GameLogEvent.error(String message) {
    return GameLogEvent(
      level: GameLogLevel.error,
      message: message,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    return '[$timestamp][$level] $message';
  }

  /// 转换为JSON格式
  Map<String, dynamic> toJson() {
    return {
      'level': level.name,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
