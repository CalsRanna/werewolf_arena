import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/events/game_log_event.dart';
import 'package:werewolf_arena/util/logger_util.dart';

/// 日志观察者实现
///
/// 这个观察者专门处理游戏引擎的日志事件，
/// 将其转换为外部日志系统的调用
///
/// 这是一个桥接模式的实现：
/// - 游戏引擎产生纯净的日志事件
/// - 外部观察者决定如何处理这些事件
/// - 保持core模块的独立性
class GameLogObserver extends GameObserverAdapter {
  /// 是否启用日志输出
  final bool enabled;

  GameLogObserver({this.enabled = true});

  @override
  void onGameLog(GameLogEvent logEvent) {
    if (!enabled) return;
    switch (logEvent.level) {
      case GameLogLevel.debug:
        LoggerUtil.instance.d(logEvent.message);
        break;
      case GameLogLevel.info:
        LoggerUtil.instance.i(logEvent.message);
        break;
      case GameLogLevel.warning:
        LoggerUtil.instance.w(logEvent.message);
        break;
      case GameLogLevel.error:
        LoggerUtil.instance.e(logEvent.message);
        break;
    }
  }
}
