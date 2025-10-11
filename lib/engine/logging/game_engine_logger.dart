import 'package:werewolf_arena/engine/logging/game_log_event.dart';
import 'package:werewolf_arena/engine/engine/game_observer.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';

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

  /// 当前游戏状态信息
  GamePhase? _currentPhase;
  int? _currentDay;

  /// 设置观察者
  void setObserver(GameObserver? observer) {
    _observer = observer;
  }

  /// 更新游戏状态信息
  void updateGameContext({GamePhase? currentPhase, int? currentDay}) {
    _currentPhase = currentPhase;
    _currentDay = currentDay;
  }

  /// 记录调试信息
  void debug(
    GameLogCategory category,
    String message, {
    Map<String, dynamic>? metadata,
  }) {
    _observer?.onGameLog(
      GameLogEvent.debug(
        category,
        message,
        phase: _currentPhase,
        dayNumber: _currentDay,
        metadata: metadata,
      ),
    );
  }

  /// 记录一般信息
  void info(
    GameLogCategory category,
    String message, {
    Map<String, dynamic>? metadata,
  }) {
    _observer?.onGameLog(
      GameLogEvent.info(
        category,
        message,
        phase: _currentPhase,
        dayNumber: _currentDay,
        metadata: metadata,
      ),
    );
  }

  /// 记录警告信息
  void warning(
    GameLogCategory category,
    String message, {
    Map<String, dynamic>? metadata,
  }) {
    _observer?.onGameLog(
      GameLogEvent.warning(
        category,
        message,
        phase: _currentPhase,
        dayNumber: _currentDay,
        metadata: metadata,
      ),
    );
  }

  /// 记录错误信息
  void error(
    GameLogCategory category,
    String message, {
    Map<String, dynamic>? metadata,
  }) {
    _observer?.onGameLog(
      GameLogEvent.error(
        category,
        message,
        phase: _currentPhase,
        dayNumber: _currentDay,
        metadata: metadata,
      ),
    );
  }
}
