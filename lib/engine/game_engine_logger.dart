import 'package:werewolf_arena/engine/events/game_log_event.dart';
import 'package:werewolf_arena/engine/game_observer.dart';

/// 游戏引擎内部日志器单例
///
/// 设计原则：
/// 1. 单例模式，全局唯一实例
/// 2. 通过observer?安全调用，可能为null
/// 3. GameState持有此单例，简化使用
/// 4. 不包含复杂的null判断逻辑
class GameEngineLogger {
  static GameEngineLogger? _instance;
  static GameEngineLogger get instance => _instance ??= GameEngineLogger._();

  GameEngineLogger._();

  /// 当前观察者（可能为null）
  GameObserver? _observer;

  /// 设置观察者
  void setObserver(GameObserver? observer) {
    _observer = observer;
  }

  /// 记录调试信息
  void d(String message) {
    _observer?.onGameEvent(GameLogEvent.debug(message));
  }

  /// 记录一般信息
  void i(String message) {
    _observer?.onGameEvent(GameLogEvent.info(message));
  }

  /// 记录警告信息
  void w(String message) {
    _observer?.onGameEvent(GameLogEvent.warning(message));
  }

  /// 记录错误信息
  void e(String message) {
    _observer?.onGameEvent(GameLogEvent.error(message));
  }
}
