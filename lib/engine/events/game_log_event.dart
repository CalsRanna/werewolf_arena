import 'package:werewolf_arena/engine/events/game_event.dart';

/// 游戏引擎内部日志事件
///
/// 这是游戏引擎向外部暴露内部运行状态的机制
/// 外部观察者可以选择如何处理这些日志（输出到文件、控制台、UI等）
class GameLogEvent extends GameEvent {
  /// 日志级别
  final GameLogLevel level;

  /// 日志消息
  final String message;

  GameLogEvent({required this.level, required this.message})
    : super(id: 'debug');

  GameLogEvent.debug(String message)
    : this(level: GameLogLevel.debug, message: message);

  GameLogEvent.error(String message)
    : this(level: GameLogLevel.error, message: message);

  GameLogEvent.info(String message)
    : this(level: GameLogLevel.info, message: message);

  GameLogEvent.warning(String message)
    : this(level: GameLogLevel.warning, message: message);

  @override
  String toNarrative() {
    var now = DateTime.now();
    return '[$now][${level.name}] $message';
  }

  @override
  String toString() {
    return 'GameLogEvent($id)';
  }
}

/// 游戏引擎日志级别
enum GameLogLevel { debug, info, warning, error }
