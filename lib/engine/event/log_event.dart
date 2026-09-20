import 'package:werewolf_arena/engine/event/game_event.dart';

/// 日志级别。公开是为了让观察者能按级别过滤（例如控制台默认只放行 warning 以上），
/// 而不必把 LogEvent 拆成一堆子类。
enum LogLevel { debug, info, warning, error }

/// 游戏引擎内部日志事件
///
/// 这是游戏引擎向外部暴露内部运行状态的机制
/// 外部观察者可以选择如何处理这些日志（输出到文件、控制台、UI等）
class LogEvent extends GameEvent {
  final String message;
  final LogLevel level;

  LogEvent(this.message) : level = LogLevel.info;

  LogEvent.debug(this.message) : level = LogLevel.debug;

  LogEvent.error(this.message) : level = LogLevel.error;

  LogEvent.info(this.message) : level = LogLevel.info;

  LogEvent.warning(this.message) : level = LogLevel.warning;

  /// 是否需要默认可见（warning 及以上）。
  bool get isProblem => level.index >= LogLevel.warning.index;

  @override
  String toNarrative() {
    var now = DateTime.now();
    return '[$now][${level.name}] $message';
  }
}
