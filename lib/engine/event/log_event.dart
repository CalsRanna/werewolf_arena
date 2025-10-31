import 'package:werewolf_arena/engine/event/game_event.dart';

/// 游戏引擎内部日志事件
///
/// 这是游戏引擎向外部暴露内部运行状态的机制
/// 外部观察者可以选择如何处理这些日志（输出到文件、控制台、UI等）
class LogEvent extends GameEvent {
  /// 日志级别
  final _LogLevel _level;

  LogEvent(String message)
    : _level = _LogLevel.info,
      super(day: 0, message: message);

  LogEvent.debug(String message)
    : _level = _LogLevel.debug,
      super(day: 0, message: message);

  LogEvent.error(String message)
    : _level = _LogLevel.error,
      super(day: 0, message: message);

  LogEvent.info(String message)
    : _level = _LogLevel.info,
      super(day: 0, message: message);

  LogEvent.warning(String message)
    : _level = _LogLevel.warning,
      super(day: 0, message: message);

  @override
  String toNarrative() {
    var now = DateTime.now();
    return '[$now][${_level.name}] $message';
  }
}

/// 游戏引擎日志级别
enum _LogLevel { debug, info, warning, error }
