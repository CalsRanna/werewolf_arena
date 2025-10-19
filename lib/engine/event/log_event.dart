import 'package:werewolf_arena/engine/event/game_event.dart';

/// 游戏引擎内部日志事件
///
/// 这是游戏引擎向外部暴露内部运行状态的机制
/// 外部观察者可以选择如何处理这些日志（输出到文件、控制台、UI等）
class LogEvent extends GameEvent {
  /// 日志级别
  final _LogLevel _level;

  /// 日志消息
  final String message;

  LogEvent({required this.message})
    : _level = _LogLevel.info,
      super(id: 'log_${DateTime.now().millisecondsSinceEpoch}');

  LogEvent.debug(this.message)
    : _level = _LogLevel.debug,
      super(id: 'log_${DateTime.now().millisecondsSinceEpoch}');

  LogEvent.error(this.message)
    : _level = _LogLevel.error,
      super(id: 'log_${DateTime.now().millisecondsSinceEpoch}');

  LogEvent.info(this.message)
    : _level = _LogLevel.info,
      super(id: 'log_${DateTime.now().millisecondsSinceEpoch}');

  LogEvent.warning(this.message)
    : _level = _LogLevel.warning,
      super(id: 'log_${DateTime.now().millisecondsSinceEpoch}');

  @override
  String toNarrative() {
    var now = DateTime.now();
    return '[$now][${_level.name}] $message';
  }

  @override
  String toString() {
    return 'LogEvent($id)';
  }
}

/// 游戏引擎日志级别
enum _LogLevel { debug, info, warning, error }
