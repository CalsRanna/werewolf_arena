import 'package:werewolf_arena/engine/event/game_event.dart';

/// 游戏引擎内部日志事件
///
/// 这是游戏引擎向外部暴露内部运行状态的机制
/// 外部观察者可以选择如何处理这些日志（输出到文件、控制台、UI等）
class LogEvent extends GameEvent {
  final String message;
  final _LogLevel _level;

  LogEvent(this.message) : _level = _LogLevel.info;

  LogEvent.debug(this.message) : _level = _LogLevel.debug;

  LogEvent.error(this.message) : _level = _LogLevel.error;

  LogEvent.info(this.message) : _level = _LogLevel.info;

  LogEvent.warning(this.message) : _level = _LogLevel.warning;

  @override
  String toNarrative() {
    var now = DateTime.now();
    return '[$now][${_level.name}] $message';
  }
}

enum _LogLevel { debug, info, warning, error }
