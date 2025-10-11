import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';

/// 游戏引擎日志级别
enum GameLogLevel { debug, info, warning, error }

/// 游戏引擎日志类别
enum GameLogCategory {
  engine, // 引擎核心逻辑
  phase, // 阶段转换
  skill, // 技能处理
  player, // 玩家行动
  event, // 事件处理
  state, // 状态变化
  victory, // 胜利条件
}

/// 游戏引擎内部日志事件
///
/// 这是游戏引擎向外部暴露内部运行状态的机制
/// 外部观察者可以选择如何处理这些日志（输出到文件、控制台、UI等）
class GameLogEvent {
  /// 日志级别
  final GameLogLevel level;

  /// 日志类别
  final GameLogCategory category;

  /// 日志消息
  final String message;

  /// 时间戳
  final DateTime timestamp;

  /// 当前游戏阶段（可选）
  final GamePhase? phase;

  /// 当前天数（可选）
  final int? dayNumber;

  /// 附加数据（可选）
  final Map<String, dynamic>? metadata;

  const GameLogEvent({
    required this.level,
    required this.category,
    required this.message,
    required this.timestamp,
    this.phase,
    this.dayNumber,
    this.metadata,
  });

  /// 创建调试日志
  factory GameLogEvent.debug(
    GameLogCategory category,
    String message, {
    GamePhase? phase,
    int? dayNumber,
    Map<String, dynamic>? metadata,
  }) {
    return GameLogEvent(
      level: GameLogLevel.debug,
      category: category,
      message: message,
      timestamp: DateTime.now(),
      phase: phase,
      dayNumber: dayNumber,
      metadata: metadata,
    );
  }

  /// 创建信息日志
  factory GameLogEvent.info(
    GameLogCategory category,
    String message, {
    GamePhase? phase,
    int? dayNumber,
    Map<String, dynamic>? metadata,
  }) {
    return GameLogEvent(
      level: GameLogLevel.info,
      category: category,
      message: message,
      timestamp: DateTime.now(),
      phase: phase,
      dayNumber: dayNumber,
      metadata: metadata,
    );
  }

  /// 创建警告日志
  factory GameLogEvent.warning(
    GameLogCategory category,
    String message, {
    GamePhase? phase,
    int? dayNumber,
    Map<String, dynamic>? metadata,
  }) {
    return GameLogEvent(
      level: GameLogLevel.warning,
      category: category,
      message: message,
      timestamp: DateTime.now(),
      phase: phase,
      dayNumber: dayNumber,
      metadata: metadata,
    );
  }

  /// 创建错误日志
  factory GameLogEvent.error(
    GameLogCategory category,
    String message, {
    GamePhase? phase,
    int? dayNumber,
    Map<String, dynamic>? metadata,
  }) {
    return GameLogEvent(
      level: GameLogLevel.error,
      category: category,
      message: message,
      timestamp: DateTime.now(),
      phase: phase,
      dayNumber: dayNumber,
      metadata: metadata,
    );
  }

  @override
  String toString() {
    final timeStr = timestamp.toString().substring(11, 19);
    final levelStr = level.name.toUpperCase().padRight(7);
    final categoryStr = category.name.toUpperCase().padRight(8);
    final phaseStr = phase != null ? '[${phase!.displayName}]' : '';
    final dayStr = dayNumber != null ? '[第$dayNumber天]' : '';

    return '$timeStr $levelStr $categoryStr $phaseStr$dayStr $message';
  }

  /// 转换为JSON格式
  Map<String, dynamic> toJson() {
    return {
      'level': level.name,
      'category': category.name,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'phase': phase?.name,
      'dayNumber': dayNumber,
      'metadata': metadata,
    };
  }
}
